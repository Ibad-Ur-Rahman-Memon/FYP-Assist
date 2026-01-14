import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_assist/widgets/chat_tab.dart';
import 'package:fyp_assist/widgets/tasks_tab.dart';
import 'package:fyp_assist/widgets/team_tab.dart';
import 'package:fyp_assist/services/firestore_service.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [];

  @override
  void initState() {
    super.initState();
    _tabs.addAll([
      TasksTab(projectId: widget.projectId),
      ChatTab(projectId: widget.projectId),
      TeamTab(projectId: widget.projectId),
    ]);
  }

  Future<void> _exportToCSV() async {
    final tasks = await ref
        .read(firestoreServiceProvider)
        .getTasksStream(widget.projectId)
        .first;
    List<List<String>> csvData = [
      ['Title', 'Description', 'Status', 'Priority', 'Due Date', 'Assignee']
    ];
    for (var task in tasks) {
      csvData.add([
        task.title,
        task.description,
        task.status,
        task.priority,
        task.dueDate?.toString() ?? '',
        task.assigneeName ?? ''
      ]);
    }
    String csv = const ListToCsvConverter().convert(csvData);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/tasks_${widget.projectName}.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Tasks export for ${widget.projectName}');
  }

  Future<void> _exportToPDF() async {
    final tasks = await ref
        .read(firestoreServiceProvider)
        .getTasksStream(widget.projectId)
        .first;
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text('Project: ${widget.projectName}',
                  style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              ...tasks.map((task) => pw.Column(
                    children: [
                      pw.Text('Title: ${task.title}',
                          style: pw.TextStyle(fontSize: 18)),
                      pw.Text('Description: ${task.description}'),
                      pw.Text('Status: ${task.status}'),
                      pw.Text('Priority: ${task.priority}'),
                      pw.Text('Due Date: ${task.dueDate?.toString() ?? 'N/A'}'),
                      pw.Text('Assignee: ${task.assigneeName ?? 'Unassigned'}'),
                      pw.SizedBox(height: 10),
                    ],
                  )),
            ],
          );
        },
      ),
    );
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/tasks_${widget.projectName}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)],
        text: 'Tasks export for ${widget.projectName}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export_csv') {
                _exportToCSV();
              } else if (value == 'export_pdf') {
                _exportToPDF();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_csv',
                child: Text('Export to CSV'),
              ),
              const PopupMenuItem(
                value: 'export_pdf',
                child: Text('Export to PDF'),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: "Tasks",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: "Chat",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: "Team & Files",
          ),
        ],
      ),
    );
  }
}
