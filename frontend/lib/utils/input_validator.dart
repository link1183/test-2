class InputValidator {
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le nom d\'utilisateur est requis';
    }

    if (!RegExp(r'^[a-zA-Z0-9@._-]+$').hasMatch(value)) {
      return 'Format de nom d\'utilisateur invalide';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    return null;
  }
}
