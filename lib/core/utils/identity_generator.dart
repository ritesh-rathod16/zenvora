import 'dart:math';

class IdentityGenerator {
  static const List<String> _prefixes = [
    "Silent", "Neon", "Shadow", "Lunar", "Nova", "Echo", "Mystic", 
    "Swift", "Frost", "Void", "Velvet", "Electric", "Dark", "Ghost",
    "Digital", "Cyber", "Stellar", "Cosmic", "Amber", "Midnight"
  ];

  static const List<String> _suffixes = [
    "Fox", "Drift", "Pixel", "Ghost", "Raven", "Owl", "Wolf", "Tiger", 
    "Panda", "Pulse", "Cipher", "Blade", "Vibe", "Storm", "Phoenix",
    "Spectre", "Rift", "Soul", "Glitch", "Aura"
  ];

  static String generate() {
    final random = Random();
    final prefix = _prefixes[random.nextInt(_prefixes.length)];
    final suffix = _suffixes[random.nextInt(_suffixes.length)];
    final number = random.nextInt(900) + 100;
    return "$prefix$suffix$number";
  }

  static String getAvatar(String name) {
    return "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=$name&backgroundColor=0f0f1a";
  }
}
