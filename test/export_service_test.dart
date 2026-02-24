import 'package:flutter_test/flutter_test.dart';
import 'package:students_checker/services/export_service.dart';

void main() {
  test('generateWordHtml generates correct HTML', () {
    // Arrange
    final students = [
      {'name': 'Alice', 'email': 'alice@example.com', 'status': 'Present', 'time': '10:00:00'},
      {'name': 'Bob', 'email': 'bob@example.com', 'status': 'Present', 'time': '10:05:00'},
    ];
    final className = 'Math 101';

    // Act
    final html = ExportService.generateWordHtml(students, className);

    // Assert
    expect(html, contains('<h1>Attendance Report: Math 101</h1>'));
    expect(html, contains('<td>Alice</td>'));
    expect(html, contains('<td>alice@example.com</td>'));
    expect(html, contains('<td>Present</td>'));
    expect(html, contains('<td>10:00:00</td>'));
    expect(html, contains('<td>Bob</td>'));
    expect(html, contains('<td>bob@example.com</td>'));
    expect(html, contains('<td>10:05:00</td>'));
    expect(html, contains('<th>Student Name</th>'));
  });
}
