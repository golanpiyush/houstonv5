import os
import json
import logging
from flask import Flask, request, jsonify, Response
from yt_dlp import YoutubeDL
from ytmusicapi import YTMusic
from concurrent.futures import ThreadPoolExecutor
import atexit
from datetime import datetime
import asyncio
import queue
from dataclasses import asdict
import threading
import uuid  # Import UUID to generate unique session IDs
from typing import Dict, Optional

from related_songs import process_song

# Initialize Flask app
app = Flask(__name__)
pref8 = '320'

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# API Key from Last.fm
API_KEY = os.getenv('LASTFM_API_KEY', 'xyg')

# YTMusic client
yt_music = YTMusic()

# Thread pool for concurrent tasks
executor = ThreadPoolExecutor(max_workers=5)
atexit.register(executor.shutdown, wait=True)

# Queue for SSE communication
event_queues: Dict[str, queue.Queue] = {}

def create_queue_for_session(session_id: str) -> queue.Queue:
    """Create a new queue for a session"""
    if session_id not in event_queues:
        event_queues[session_id] = queue.Queue()
    return event_queues[session_id]

def format_sse(data: str, event=None) -> str:
    """Format data for SSE"""
    msg = f'data: {data}\n\n'
    if event is not None:
        msg = f'event: {event}\n{msg}'
    return msg

def send_song_info(song_info, session_id: str, index=None, event_type="related_song"):
    """Send song info through the event queue"""
    if song_info and session_id in event_queues:
        song_dict = asdict(song_info)
        if index is not None:
            song_dict['index'] = index
        event_queues[session_id].put((event_type, song_dict))

async def process_related_songs(query: str, session_id: str):
    """Process related songs and send via SSE"""
    try:
        loop = asyncio.get_event_loop()
        search_results = await loop.run_in_executor(
            None,
            lambda: yt_music.search(query, filter="songs", limit=1)
        )
        
        if not search_results:
            event_queues[session_id].put(("error", {"message": "No related songs found"}))
            return
            
        main_song = await process_song(yt_music, search_results[0])
        if main_song:
            related_data = await loop.run_in_executor(
                None,
                lambda: yt_music.get_watch_playlist(videoId=main_song.video_id)
            )
            
            related_tracks = related_data.get('tracks', [])[:8]
            
            for index, track in enumerate(related_tracks, 1):
                if track.get('videoId') == main_song.video_id:
                    continue
                    
                song = await process_song(yt_music, track, main_song.video_id, index)
                if song:
                    send_song_info(song, session_id, index)
        
        # Signal completion
        event_queues[session_id].put(("complete", {"message": "Related songs processing complete"}))
        
    except Exception as e:
        logger.error(f"Error processing related songs: {e}")
        event_queues[session_id].put(("error", {"message": str(e)}))

def run_async_processing(query: str, session_id: str):
    """Run async processing in a separate thread"""
    async def async_wrapper():
        await process_related_songs(query, session_id)
    
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(async_wrapper())
    loop.close()

def fetch_song_details(song_name):
    try:
        search_results = yt_music.search(song_name, filter='songs', limit=1)
        if search_results:
            song_info = search_results[0]
            title = song_info.get('title')
            artists = ", ".join([artist['name'] for artist in song_info['artists']])
            video_id = song_info.get('videoId')

            if video_id:
                song_details = yt_music.get_song(video_id)
                thumbnails = song_details.get('videoDetails', {}).get('thumbnail', {}).get('thumbnails', [])
                album_art = sorted(thumbnails, key=lambda x: (x.get('width', 0), x.get('height', 0)))[-1]['url'] if thumbnails else 'No album art found'
            else:
                album_art = 'No album art found'
            print(f"Album Art URL: {album_art}")

            ydl_opts = {
                'format': 'bestaudio/best',
                'noplaylist': True,
                'quiet': True,
                'extractaudio': True,
                'postprocessors': [{
                    'key': 'FFmpegExtractAudio',
                    'preferredcodec': 'mp3',
                    'preferredquality': pref8,
                }],
            }

            with YoutubeDL(ydl_opts) as ydl:
                info_dict = ydl.extract_info(f"ytsearch:{song_name} Official Audio", download=False)
                audio_url = info_dict['entries'][0]['url'] if info_dict['entries'] else 'No audio URL found'

            return {
                'title': title,
                'artists': artists,
                'albumArt': album_art,
                'audioUrl': audio_url,
                'videoId': video_id  # Added video_id for related songs processing
            }
        else:
            return None
    except Exception as e:
        logger.error(f"Error fetching song details: {e}")
        return None

@app.route('/get_song', methods=['POST'])
def get_song():
    """Main endpoint for getting song details and initiating related songs processing"""
    data = request.json
    song_name = data.get('song_name')
    username = data.get('username')
    session_id = data.get('session_id')

    # Generate session_id if not provided
    if not session_id:
        session_id = str(uuid.uuid4())  # Generate a unique session ID if not provided

    if not all([song_name, username]):
        return jsonify({'error': 'Missing required fields'}), 400

    # Create queue for this session
    create_queue_for_session(session_id)

    song_details = fetch_song_details(song_name)
    if song_details:
        song_details['requested_by'] = username

        # Start related songs processing in background
        search_query = f"{song_details['title']} {song_details['artists']}"
        thread = threading.Thread(
            target=run_async_processing,
            args=(search_query, session_id)
        )
        thread.daemon = True
        thread.start()

        response_data = {
            'song_details': song_details,
            'message': 'Song details sent successfully. Connect to /stream-related to receive related songs.',
            'session_id': session_id
        }
        return jsonify(response_data), 200

    return jsonify({'error': 'No results found'}), 404

@app.route('/stream_related_songs/<session_id>')
def stream_related(session_id):
    """SSE endpoint for streaming related songs"""
    if session_id not in event_queues:
        return jsonify({'error': 'Invalid session ID'}), 404

    def generate():
        while True:
            try:
                event_type, data = event_queues[session_id].get(timeout=30)
                yield format_sse(json.dumps(data), event=event_type)
                if event_type in ["complete", "error"]:
                    # Clean up queue after completion
                    del event_queues[session_id]
                    break
            except queue.Empty:
                yield ': keepalive\n\n'
    
    return Response(
        generate(),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
        }
    )

if __name__ == "__main__":
    logger.info("Starting server")
    app.run(debug=True, threaded=True)
