from src.core.rate_limiting import RateLimitRule


# Bütün API için IP başına kaba trafik korumasıdır.
GLOBAL_IP = RateLimitRule(
    name="global-ip-minute",
    limit=600,
    window_seconds=60,
)


# Bütün uygulamanın kapasitesini koruyan acil durum sınırıdır.
GLOBAL_SYSTEM = RateLimitRule(
    name="global-system-minute",
    limit=10_000,
    window_seconds=60,
)


# Login IP sınırının kısa penceresidir.
LOGIN_IP_MINUTE = RateLimitRule(
    name="login-ip-minute",
    limit=5,
    window_seconds=60,
)


# Login IP sınırının uzun penceresidir.
LOGIN_IP_HOUR = RateLimitRule(
    name="login-ip-hour",
    limit=50,
    window_seconds=3_600,
)


# Tek hesabı dağıtık parola denemelerine karşı korur.
LOGIN_ACCOUNT = RateLimitRule(
    name="login-account-15m",
    limit=5,
    window_seconds=15 * 60,
)


# Aynı IP ile aynı hesaba yapılan denemeleri sınırlar.
LOGIN_IP_ACCOUNT = RateLimitRule(
    name="login-ip-account-5m",
    limit=5,
    window_seconds=5 * 60,
)


# Aynı IP'nin bir saatte açabileceği hesap sayısını sınırlar.
REGISTER_IP_HOUR = RateLimitRule(
    name="register-ip-hour",
    limit=3,
    window_seconds=3_600,
)


# Aynı IP'nin bir günde açabileceği hesap sayısını sınırlar.
REGISTER_IP_DAY = RateLimitRule(
    name="register-ip-day",
    limit=10,
    window_seconds=24 * 3_600,
)


# Refresh endpoint'inin IP sınırıdır.
REFRESH_IP = RateLimitRule(
    name="refresh-ip-minute",
    limit=20,
    window_seconds=60,
)


# Aynı refresh token parmak izinin kullanımını sınırlar.
REFRESH_FINGERPRINT = RateLimitRule(
    name="refresh-fingerprint-minute",
    limit=10,
    window_seconds=60,
)


# Normal API trafiğinde kullanıcı sınırıdır.
AUTHENTICATED_USER = RateLimitRule(
    name="authenticated-user-minute",
    limit=120,
    window_seconds=60,
)


# Normal API trafiğinde IP sınırıdır.
AUTHENTICATED_IP = RateLimitRule(
    name="authenticated-ip-minute",
    limit=300,
    window_seconds=60,
)


# Veri değiştiren endpoint'lerde kullanıcı sınırıdır.
MUTATION_USER = RateLimitRule(
    name="mutation-user-minute",
    limit=60,
    window_seconds=60,
)


# Statistics endpoint'inin kullanıcı sınırıdır.
STATISTICS_USER = RateLimitRule(
    name="statistics-user-minute",
    limit=30,
    window_seconds=60,
)


# Gelecekte e-posta gönderim endpoint'inde kullanılacaktır.
EMAIL_SEND_ACCOUNT = RateLimitRule(
    name="email-send-account-hour",
    limit=3,
    window_seconds=3_600,
)


# Gelecekte e-posta doğrulama kontrolünde kullanılacaktır.
EMAIL_VERIFICATION_CHECK = RateLimitRule(
    name="email-verification-check-minute",
    limit=10,
    window_seconds=60,
)


# Gelecekte export ve rapor endpoint'lerinde kullanılacaktır.
EXPORT_USER = RateLimitRule(
    name="export-user-minute",
    limit=5,
    window_seconds=60,
)


GOOGLE_LOGIN_IP_MINUTE = RateLimitRule(
    name="google-login-ip-minute",
    limit=10,
    window_seconds=60,
)

GOOGLE_LOGIN_IP_HOUR = RateLimitRule(
    name="google-login-ip-hour",
    limit=100,
    window_seconds=3_600,
)

GOOGLE_LOGIN_TOKEN = RateLimitRule(
    name="google-login-token-minute",
    limit=5,
    window_seconds=60,
)