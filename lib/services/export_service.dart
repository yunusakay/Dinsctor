class ExportService {
  static String generateWordHtml(List<Map<String, String>> students, String className) {
    StringBuffer html = StringBuffer();
    html.writeln('<html><body>');
    html.writeln('<h1>Attendance Report: $className</h1>');
    html.writeln('<p>Date: ${DateTime.now().toString().split(' ')[0]}</p>');
    html.writeln('<p>Total Students: ${students.length}</p>');
    html.writeln('<table border="1" cellpadding="5" cellspacing="0">');
    html.writeln('<tr><th>Student Name</th><th>Email</th><th>Status</th><th>Time</th></tr>');

    for (var student in students) {
      html.writeln('<tr>');
      html.writeln('<td>${student['name'] ?? "Unknown"}</td>');
      html.writeln('<td>${student['email'] ?? "No Email"}</td>');
      html.writeln('<td>${student['status'] ?? "Unknown"}</td>');
      html.writeln('<td>${student['time'] ?? "Unknown Time"}</td>');
      html.writeln('</tr>');
    }
    html.writeln('</table>');
    html.writeln('</body></html>');

    return html.toString();
  }
}
