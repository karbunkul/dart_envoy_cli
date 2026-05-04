class Config {
  bool get debugMode => {{debug_mode}};
  String get baseAuth => '{{#base64}} {{base_auth}} {{/base64}}';
  String get gitBranch => '{{git_branch}}';
  int get port => {{port}};
}
