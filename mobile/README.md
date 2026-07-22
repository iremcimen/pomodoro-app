# Pomo Flutter

Android, iOS ve Web için tek kod tabanlı Pomo istemcisi. Authentication akışı,
backend'in `/api/v1/auth` sözleşmesine bağlıdır ve Riverpod ile yönetilir.

## Mimari

Proje feature-first clean architecture kullanır:

```text
lib/
├── app/                    # Router, tema ve uygulama composition root'u
├── core/                   # Ortam config'i, ortak hata ve doğrulama kuralları
└── features/
    ├── auth/
    │   ├── presentation/   # Responsive ekranlar ve tekrar kullanılabilir widget'lar
    │   ├── application/    # Riverpod controller ve dependency composition
    │   ├── domain/         # Framework bağımsız entity/repository sözleşmeleri
    │   └── data/           # Dio API, secure storage ve repository implementasyonu
    └── home/               # Kimliği doğrulanmış başlangıç ekranı
```

Bağımlılık yönü `presentation → application → domain` şeklindedir. `data`
katmanı domain sözleşmelerini uygular. UI; Dio, JSON veya token saklama ayrıntılarını
bilmez.

## Çalıştırma

Bağımlılıkları kurun:

```bash
flutter pub get
```

Android emülatörü varsayılan olarak `http://10.0.2.2:8000/api/v1`, iOS
simülatörü ve Web ise `http://localhost:8000/api/v1` kullanır:

```bash
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

Fiziksel cihaz, staging veya production için URL'yi build-time verin:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Production ortamında API mutlaka HTTPS olmalıdır. Web geliştirmede backend'in
Flutter origin'ine (ör. `http://localhost:<port>`) CORS izni vermesi gerekir.

## Authentication davranışı

- Login, backend sözleşmesine göre e-posta veya kullanıcı adı kabul eder.
- Register; e-posta, kullanıcı adı, isteğe bağlı ad soyad ve şifre gönderir.
- Access/refresh token çifti `flutter_secure_storage` ile platform güvenli
  deposunda tutulur.
- Süresi dolan access token uygulama açılışında refresh edilir.
- Logout çağrısı başarısız olsa bile yerel tokenlar temizlenir.
- Route guard, oturumsuz erişimi `/login` sayfasına yönlendirir.

## Kalite kontrolleri

```bash
flutter analyze
flutter test
flutter build web --release
```

Testler backend ile uyumlu input kurallarını ve hem dar hem geniş viewport auth
yerleşimlerini kapsar.
