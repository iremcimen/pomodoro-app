abstract final class InputValidators {
  static final _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  );
  static final _usernamePattern = RegExp(r'^[a-z0-9_]+$');

  static String? required(String? value, {String label = 'Bu alan'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label zorunludur.';
    }
    return null;
  }

  static String? loginIdentifier(String? value) {
    final requiredError = required(value, label: 'E-posta veya kullanıcı adı');
    if (requiredError != null) return requiredError;

    final normalized = value!.trim().toLowerCase();
    if (normalized.contains('@')) {
      return email(normalized);
    }

    return username(normalized);
  }

  static String? email(String? value) {
    final requiredError = required(value, label: 'E-posta');
    if (requiredError != null) return requiredError;
    if (value!.length > 320 || !_emailPattern.hasMatch(value.trim())) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  static String? username(String? value) {
    final requiredError = required(value, label: 'Kullanıcı adı');
    if (requiredError != null) return requiredError;
    final normalized = value!.trim().toLowerCase();
    if (normalized.length < 3 || normalized.length > 50) {
      return 'Kullanıcı adı 3-50 karakter olmalıdır.';
    }
    if (!_usernamePattern.hasMatch(normalized)) {
      return 'Yalnızca küçük harf, sayı ve alt çizgi kullanın.';
    }
    return null;
  }

  static String? fullName(String? value) {
    if (value != null && value.trim().length > 100) {
      return 'Ad soyad en fazla 100 karakter olabilir.';
    }
    return null;
  }

  static String? password(String? value) {
    final requiredError = required(value, label: 'Şifre');
    if (requiredError != null) return requiredError;
    if (value!.length < 8 || value.length > 128) {
      return 'Şifre 8-128 karakter olmalıdır.';
    }
    return null;
  }
}
