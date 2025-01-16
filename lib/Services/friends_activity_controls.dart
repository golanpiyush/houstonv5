import 'dart:async';

class FriendActivityControls {
  // Stores current user activity (song name, artist, etc.)
  Map<String, Map<String, dynamic>> userActivity = {};

  // Stores friend requests: user -> set of friend requests
  Map<String, Set<String>> friendRequests = {};

  // Stores friendships: user -> set of friends
  Map<String, Set<String>> friendships = {};

  // StreamController to broadcast activity updates to the UI
  final StreamController<Map<String, dynamic>> _activityController =
      StreamController.broadcast();

  // Function to send activity updates
  void sendActivity(String username, String songName, String artistName,
      String? profilePicture) {
    // Save activity
    userActivity[username] = {
      'song_name': songName,
      'artist_name': artistName,
      'profile_picture': profilePicture,
    };

    // Broadcast activity to all friends (if any)
    if (friendships.containsKey(username)) {
      for (var friend in friendships[username]!) {
        // Send the activity update to each friend
        _activityController.add({
          'friend': friend,
          'username': username,
          'song_name': songName,
          'artist_name': artistName,
          'profile_picture': profilePicture,
        });
      }
    }
  }

  // Function to send a friend request
  void sendFriendRequest(String fromUser, String toUser) {
    if (!friendRequests.containsKey(toUser)) {
      friendRequests[toUser] = <String>{};
    }
    friendRequests[toUser]!.add(fromUser);
  }

  // Function to accept a friend request
  void acceptFriendRequest(String fromUser, String toUser) {
    if (friendRequests.containsKey(toUser) &&
        friendRequests[toUser]!.contains(fromUser)) {
      // Remove from friend requests
      friendRequests[toUser]!.remove(fromUser);

      // Add the friend to both users' friendship lists
      if (!friendships.containsKey(toUser)) {
        friendships[toUser] = <String>{};
      }
      if (!friendships.containsKey(fromUser)) {
        friendships[fromUser] = <String>{};
      }

      friendships[toUser]!.add(fromUser);
      friendships[fromUser]!.add(toUser);
    }
  }

  // Function to reject a friend request
  void rejectFriendRequest(String fromUser, String toUser) {
    if (friendRequests.containsKey(toUser)) {
      friendRequests[toUser]!.remove(fromUser);
    }
  }

  // Function to get the activity stream (to be used in the UI)
  Stream<Map<String, dynamic>> getActivityStream() {
    return _activityController.stream;
  }

  // Function to get the list of friends for a specific user
  List<String> getFriends(String username) {
    return friendships[username]?.toList() ?? [];
  }

  // Function to check if two users are friends
  bool areFriends(String user1, String user2) {
    return friendships.containsKey(user1) &&
        friendships[user1]!.contains(user2);
  }

  // Function to get the friend requests for a specific user
  Set<String> getFriendRequests(String username) {
    return friendRequests[username] ?? {};
  }

  // Cleanup: Close the stream when no longer needed
  void dispose() {
    _activityController.close();
  }
}
