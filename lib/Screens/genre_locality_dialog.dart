import 'package:flutter/material.dart';

class GenreLocalityDialog extends StatefulWidget {
  const GenreLocalityDialog({super.key});

  @override
  _GenreLocalityDialogState createState() => _GenreLocalityDialogState();
}

class _GenreLocalityDialogState extends State<GenreLocalityDialog> {
  final List<String> genres = [
    'Pop',
    'EDM',
    'Rock',
    'Hip-hop',
    'Jazz',
    'Classical',
    'Country'
  ];
  final List<String> localities = [
    'Indian',
    'American',
    'British',
    'Korean',
    'Japanese',
    'Latin',
    'Australian'
  ];

  final List<String> selectedGenres = [];
  final List<String> selectedLocalities = [];

  bool isLocalityStep = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        isLocalityStep ? 'Select Localities' : 'Select Genres',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isLocalityStep) ...[
              const Text('Genres:', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Column(
                children: genres.map((genre) {
                  return CheckboxListTile(
                    title: Text(genre),
                    value: selectedGenres.contains(genre),
                    onChanged: (isChecked) {
                      setState(() {
                        if (isChecked == true) {
                          selectedGenres.add(genre);
                        } else {
                          selectedGenres.remove(genre);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ] else ...[
              const Text('Localities:', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Column(
                children: localities.map((locality) {
                  return CheckboxListTile(
                    title: Text(locality),
                    value: selectedLocalities.contains(locality),
                    onChanged: (isChecked) {
                      setState(() {
                        if (isChecked == true) {
                          selectedLocalities.add(locality);
                        } else {
                          selectedLocalities.remove(locality);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (isLocalityStep)
          TextButton(
            onPressed: () {
              setState(() {
                isLocalityStep = false;
              });
            },
            child: const Text('Back'),
          ),
        TextButton(
          onPressed: () {
            if (isLocalityStep) {
              Navigator.of(context).pop({
                'genres': selectedGenres,
                'localities': selectedLocalities,
              });
            } else {
              if (selectedGenres.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please select at least one genre.')),
                );
              } else {
                setState(() {
                  isLocalityStep = true;
                });
              }
            }
          },
          child: Text(isLocalityStep ? 'Finish' : 'Continue'),
        ),
      ],
    );
  }
}
