import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/services.dart';

class MemoriesPage extends StatelessWidget {
  const MemoriesPage({super.key});

  Future<void> capture(
    BuildContext context,
    ImageSource source, {
    bool video = false,
  }) async {
    final picker = ImagePicker();

    final XFile? file = video
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(
            source: source,
            imageQuality: 88,
          );

    if (file == null || !context.mounted) return;

    final titleController = TextEditingController();
    final storyController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            MediaQuery.viewInsetsOf(bottomSheetContext).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  video ? 'Save video memory' : 'Save photo memory',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Memory title',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: storyController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Tell the story',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      showDialog(
                        context: bottomSheetContext,
                        barrierDismissible: false,
                        builder: (_) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      try {
                        final url = await MediaStore.upload(
                          File(file.path),
                          video ? 'video' : 'photo',
                        );

                        await DB.memories.add({
                          'title': titleController.text.trim().isEmpty
                              ? 'A moment to remember'
                              : titleController.text.trim(),
                          'story': storyController.text.trim(),
                          'mediaUrl': url,
                          'mediaType': video ? 'video' : 'photo',
                          'favorite': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        if (bottomSheetContext.mounted) {
                          Navigator.pop(bottomSheetContext);
                          Navigator.pop(bottomSheetContext);
                        }
                      } catch (e) {
                        if (bottomSheetContext.mounted) {
                          Navigator.pop(bottomSheetContext);

                          ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not upload memory: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Save memory'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    titleController.dispose();
    storyController.dispose();
  }

  void menu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  capture(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Record a video'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  capture(
                    context,
                    ImageSource.camera,
                    video: true,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  capture(context, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => menu(context),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Capture'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DB.memories
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final documents = snapshot.data?.docs ?? [];

          return CustomScrollView(
            slivers: [
              const SliverAppBar(
                backgroundColor: Colors.transparent,
                floating: true,
                title: Text(
                  'Memories',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                  ),
                ),
              ),

              if (documents.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Your memory vault is waiting.\n'
                      'Capture a photo, video or moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 18,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    5,
                    12,
                    100,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: .72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final document = documents[index];
                      final data = document.data();
                      final url = data['mediaUrl'] ?? '';

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (dialogContext) {
                                return Dialog(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (url.isNotEmpty &&
                                            data['mediaType'] == 'photo')
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            child: Image.network(
                                              url,
                                              height: 260,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                        Text(
                                          data['title'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(data['story'] ?? ''),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                ShareService.text(
                                                  '${data['title']}\n'
                                                  '${data['story']}\n'
                                                  '$url',
                                                );
                                              },
                                              icon: const Icon(Icons.share),
                                            ),
                                            IconButton(
                                              onPressed: () async {
                                                await document.reference
                                                    .delete();

                                                if (dialogContext.mounted) {
                                                  Navigator.pop(
                                                    dialogContext,
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: url.isEmpty
                                    ? Container(
                                        color: Colors.white10,
                                        child: const Center(
                                          child: Icon(
                                            Icons.auto_awesome,
                                            size: 40,
                                          ),
                                        ),
                                      )
                                    : data['mediaType'] == 'photo'
                                        ? Image.network(
                                            url,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Color(0xFF25184D),
                                                  Color(0xFF0E4660),
                                                ],
                                              ),
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.play_circle_fill,
                                                size: 54,
                                              ),
                                            ),
                                          ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        data['title'] ?? 'Memory',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        document.reference.update({
                                          'favorite':
                                              !(data['favorite'] == true),
                                        });
                                      },
                                      icon: Icon(
                                        data['favorite'] == true
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}