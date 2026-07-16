enum AccountProviderType {
  claude,
  codex,
  antigravity,
  copilot;

  String get id => name;

  String get displayName => switch (this) {
        AccountProviderType.claude => 'Claude',
        AccountProviderType.codex => 'Codex (ChatGPT)',
        AccountProviderType.antigravity => 'Antigravity (Google)',
        AccountProviderType.copilot => 'GitHub Copilot',
      };

  String get defaultLoginUrl => switch (this) {
        AccountProviderType.claude => 'https://claude.ai/login',
        AccountProviderType.codex => 'https://chatgpt.com/',
        AccountProviderType.antigravity => 'https://aistudio.google.com/',
        AccountProviderType.copilot => 'https://github.com/login',
      };

  String get cookieDomainUrl => switch (this) {
        AccountProviderType.claude => 'https://claude.ai',
        AccountProviderType.codex => 'https://chatgpt.com',
        AccountProviderType.antigravity => 'https://google.com',
        AccountProviderType.copilot => 'https://github.com',
      };

  String get pingUrl => switch (this) {
        AccountProviderType.claude => 'https://claude.ai/new',
        AccountProviderType.codex => 'https://chatgpt.com/',
        AccountProviderType.antigravity => 'https://aistudio.google.com/',
        AccountProviderType.copilot => 'https://github.com/settings/billing',
      };

  static AccountProviderType fromString(String? val) {
    if (val == 'codex') return AccountProviderType.codex;
    if (val == 'antigravity') return AccountProviderType.antigravity;
    if (val == 'copilot') return AccountProviderType.copilot;
    return AccountProviderType.claude;
  }
}
