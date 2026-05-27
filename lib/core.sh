#!/bin/bash
# Core: colors, translations, utilities

COLOR_RESET="\033[0m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_WHITE="\033[1;37m"
COLOR_RED="\033[1;31m"
COLOR_CYAN="\033[1;36m"
COLOR_GRAY="\033[0;90m"

declare -gA LANG

load_lang_en() {
    LANG[LANG_SELECT]="Select language / Выберите язык:"
    LANG[LANG_EN]="English"
    LANG[LANG_RU]="Русский"
    LANG[ERROR_ROOT]="This script must be run as root."
    LANG[ERROR_OS]="Unsupported OS. Supported: Debian 11/12, Ubuntu 22/24."
    LANG[EXIT]="Cancelled."
    LANG[INVALID_CHOICE]="Invalid choice."
    LANG[CONFIRM_PROMPT]="Continue anyway? [y/N]: "

    LANG[MENU_TITLE]="Remnawave Installer"
    LANG[MENU_1]="Install Panel"
    LANG[MENU_2]="Install Node"
    LANG[MENU_3]="Add Node to existing Panel"
    LANG[MENU_4]="Manage Services"
    LANG[MENU_5]="Manage SSL Certificates"
    LANG[MENU_6]="Manage IPv6"
    LANG[MENU_0]="Exit"
    LANG[PROMPT_ACTION]="Select option"

    LANG[ENTER_PANEL_DOMAIN]="Panel domain (e.g. panel.example.com)"
    LANG[ENTER_SUB_DOMAIN]="Subscription domain (e.g. sub.example.com)"
    LANG[ENTER_SELFSTEAL_DOMAIN]="SelfSteal domain — the camouflage site (e.g. steal.example.com)"
    LANG[DOMAINS_MUST_BE_UNIQUE]="All three domains must be different."
    LANG[WARNING_LABEL]="WARNING:"
    LANG[CHECK_DOMAIN_IP_FAIL]="Could not verify domain DNS. Check that A record exists."
    LANG[CHECK_DOMAIN_MISMATCH]="Domain %s points to %s but this server IP is %s."
    LANG[CHECK_DOMAIN_MISMATCH_INSTRUCTION]="Make sure the DNS A record points to this server."
    LANG[CHECK_DOMAIN_CLOUDFLARE]="Domain %s is proxied via Cloudflare (%s). This breaks XRAY Reality!"
    LANG[CHECK_DOMAIN_CLOUDFLARE_INSTRUCTION]="Disable Cloudflare proxy (grey cloud) for node/selfsteal domains."

    LANG[CERT_METHOD_PROMPT]="Choose SSL certificate method:"
    LANG[CERT_METHOD_CF]="Cloudflare DNS-01 (wildcard, recommended)"
    LANG[CERT_METHOD_ACME]="ACME HTTP-01 (standalone, per-domain)"
    LANG[EMAIL_PROMPT]="Email for Let's Encrypt notifications"
    LANG[ENTER_CF_TOKEN]="Cloudflare API Token (or Global Key)"
    LANG[ENTER_CF_EMAIL]="Cloudflare account email (for Global Key only)"
    LANG[CF_VALIDATING]="Cloudflare credentials validated."
    LANG[CF_INVALID_ATTEMPT]="Invalid credentials (attempt %s/%s). Try again."
    LANG[CF_INVALID]="Cloudflare validation failed after %s attempts."
    LANG[GENERATING_CERTS]="Generating SSL certificate for %s..."
    LANG[CERT_FOUND]="Certificate found: "
    LANG[WILDCARD_CERT_FOUND]="Wildcard certificate found: "
    LANG[FOR_DOMAIN]="covers domain"
    LANG[CERT_NOT_FOUND]="Certificate not found for"
    LANG[CERTS_SKIPPED]="Certificates already exist, skipping generation."
    LANG[CERT_GENERATION_FAILED]="Certificate generation failed for"
    LANG[ADDING_CRON]="Adding weekly certbot renewal to cron..."

    LANG[INSTALL_PACKAGES]="Installing required packages (Docker, certbot, ufw, jq...)..."
    LANG[SUCCESS_INSTALL]="All packages installed successfully."
    LANG[ERROR_INSTALL_PACKAGES]="Failed to install packages."
    LANG[ERROR_INSTALL_DOCKER]="Failed to install Docker."

    LANG[SUMMARY_TITLE]="===== Installation Summary ====="
    LANG[SUMMARY_CONFIRM]="Start installation with these settings? [y/N]"

    LANG[STARTING_PANEL]="Starting Docker containers..."
    LANG[WAITING]="Please wait..."
    LANG[REGISTERING_REMNAWAVE]="Waiting for Remnawave API to become ready..."
    LANG[CHECK_CONTAINERS]="Checking container health..."
    LANG[CONTAINERS_NOT_READY_ATTEMPT]="Containers not ready (attempt %s/%s), retrying in 60s..."
    LANG[CONTAINERS_TIMEOUT]="Containers failed to start after %s attempts. Check: docker compose logs"
    LANG[REGISTRATION_SUCCESS]="Superadmin registered."
    LANG[GENERATE_KEYS]="Generating XRAY x25519 keypair..."
    LANG[GENERATE_KEYS_SUCCESS]="Keys generated."
    LANG[CREATING_CONFIG_PROFILE]="Creating XRAY config profile..."
    LANG[CONFIG_PROFILE_CREATED]="Config profile created."
    LANG[CREATING_NODE]="Creating node record in panel..."
    LANG[NODE_CREATED]="Node record created."
    LANG[CREATE_HOST]="Creating host record..."
    LANG[HOST_CREATED]="Host created."
    LANG[GET_DEFAULT_SQUAD]="Fetching default squad list..."
    LANG[UPDATE_SQUAD]="Squad updated with new inbound."
    LANG[CREATING_API_TOKEN]="Creating API token for subscription page..."
    LANG[API_TOKEN_ADDED]="API token created and injected."
    LANG[STOPPING_SUB_PAGE]="Restarting subscription page container..."
    LANG[INSTALL_COMPLETE]="Installation complete!"
    LANG[PANEL_ACCESS]="Panel URL (bookmark this):"
    LANG[ADMIN_CREDS]="Admin credentials:"
    LANG[USERNAME]="  Login:    "
    LANG[PASSWORD]="  Password: "
    LANG[RELAUNCH_CMD]="To manage panel/node, run:"

    LANG[ENTER_PANEL_IP]="Panel server IP address"
    LANG[IP_ERROR]="Invalid IPv4 address. Try again."
    LANG[ENTER_PUBLIC_KEY]="Public Key from Panel (Panel → Nodes → Public Key)"
    LANG[STARTING_NODE]="Starting node containers..."
    LANG[NODE_LAUNCHED]="Node is responding on HTTPS."
    LANG[NODE_CHECK]="Verifying node HTTPS at %s..."
    LANG[NODE_ATTEMPT]="Attempt %s of %s..."
    LANG[NODE_UNAVAILABLE]="Not responding yet (attempt %s). Retrying in 15s..."
    LANG[NODE_NOT_CONNECTED]="Node did not respond after %s attempts."
    LANG[CHECK_CONFIG]="Debug: cd /opt/remnanode && docker compose logs -f"
    LANG[NODE_INSTALL_COMPLETE]="Node installation complete!"
    LANG[NODE_HINT]="The node is now listening on port 2222 for panel connections."

    LANG[WARNING_NODE_PANEL]="This runs API calls against 127.0.0.1:3000 — run on the PANEL server."
    LANG[CONFIRM_SERVER_PANEL]="Are you on the panel server? [y/N]"
    LANG[ADD_NODE_TO_PANEL]="Adding node configuration to panel..."
    LANG[ENTER_NODE_DOMAIN]="Node domain (e.g. node1.example.com)"
    LANG[ENTER_NODE_NAME]="Node name (3-20 chars, letters/digits/hyphen)"
    LANG[TRY_ANOTHER_DOMAIN]="Domain already registered in panel. Choose another."
    LANG[CF_INVALID_NAME]="Name '%s' already exists. Choose another."
    LANG[CF_INVALID_LENGTH]="Name must be 3-20 characters."
    LANG[CF_INVALID_CHARS]="Name must only contain letters, digits, and hyphens."
    LANG[NODE_ADDED_SUCCESS]="Node configuration added to panel."
    LANG[POST_PANEL_INSTRUCTION]="Next step: install the node on the node server using option 2."

    LANG[ERROR_TOKEN]="Failed to obtain authentication token."
    LANG[USING_SAVED_TOKEN]="Using saved token..."
    LANG[INVALID_SAVED_TOKEN]="Saved token is invalid or expired."
    LANG[TOKEN_RECEIVED_AND_SAVED]="Token saved."
    LANG[TOKEN_USED_SUCCESSFULLY]="Token is valid."
    LANG[ENTER_PANEL_USERNAME]="Panel admin username"
    LANG[ENTER_PANEL_PASSWORD]="Panel admin password"
    LANG[NO_SQUADS_TO_UPDATE]="No squads found to update."
    LANG[UPDATING_SQUAD]="Updating squad:"
    LANG[ERROR_UPDATE_SQUAD]="Failed to update squad:"
    LANG[ERROR_GET_SQUAD_LIST]="Failed to fetch squad list."
    LANG[DOMAIN_ALREADY_EXISTS]="Domain already exists in panel:"
    LANG[ERROR_CHECK_DOMAIN]="Failed to check domain:"
    LANG[ERROR_GENERATE_KEYS]="Failed to generate XRAY keys."
    LANG[ERROR_EXTRACT_PRIVATE_KEY]="Failed to extract private key from API response."
    LANG[ERROR_CREATE_CONFIG_PROFILE]="Failed to create config profile:"
    LANG[ERROR_EMPTY_RESPONSE_NODE]="Empty API response (create node)."
    LANG[ERROR_CREATE_NODE]="Failed to create node."
    LANG[ERROR_EMPTY_RESPONSE_HOST]="Empty API response (create host)."
    LANG[ERROR_CREATE_HOST]="Failed to create host."
    LANG[ERROR_GET_SQUAD]="Failed to get squads:"
    LANG[NO_SQUADS_FOUND]="No squads found."
    LANG[INVALID_UUID_FORMAT]="Invalid UUID format:"
    LANG[NO_VALID_SQUADS_FOUND]="No valid squad UUIDs found."
    LANG[INVALID_SQUAD_UUID]="Invalid squad UUID:"
    LANG[INVALID_INBOUND_UUID]="Invalid inbound UUID:"
    LANG[ERROR_CREATE_API_TOKEN]="Failed to create API token:"
    LANG[ERROR_PUBLIC_KEY]="Failed to get public key from panel."
    LANG[ERROR_EXTRACT_PUBLIC_KEY]="Failed to extract public key from response."
    LANG[PUBLIC_KEY_SUCCESS]="Public key set in node config."
    LANG[ERROR_EMPTY_RESPONSE_REGISTER]="Empty API response during registration."
    LANG[ERROR_REGISTER]="Registration failed:"
    LANG[NO_DEFAULT_PROFILE]="Default-Profile not found (already deleted)."
    LANG[ERROR_NO_CONFIGS]="Failed to fetch config profiles."
    LANG[ERROR_DELETE_PROFILE]="Failed to delete Default-Profile."

    LANG[MANAGE_TITLE]="Manage Services"
    LANG[MANAGE_1]="Start services"
    LANG[MANAGE_2]="Stop services"
    LANG[MANAGE_3]="Update Docker images"
    LANG[MANAGE_4]="View logs (Ctrl+C to exit)"
    LANG[MANAGE_5]="Remnawave CLI"
    LANG[MANAGE_6]="Open/close emergency port 8443"
    LANG[PANEL_RUNNING]="Services are already running."
    LANG[PANEL_STOPPED]="Services are already stopped."
    LANG[STARTING_SERVICES]="Starting services..."
    LANG[STOPPING_SERVICES]="Stopping services..."
    LANG[SERVICES_STARTED]="Services started."
    LANG[SERVICES_STOPPED]="Services stopped."
    LANG[UPDATING_IMAGES]="Pulling latest images..."
    LANG[NEW_IMAGES]="New images found. Restarting services..."
    LANG[UPDATE_DONE]="Update complete."
    LANG[ALREADY_LATEST]="All images are already up to date."
    LANG[DIR_NOT_FOUND]="No installation found at /opt/remnawave or /opt/remnanode."
    LANG[CONTAINER_NOT_RUNNING]="Container 'remnawave' is not running."
    LANG[RUNNING_CLI]="Launching Remnawave CLI..."
    LANG[CLI_DONE]="CLI session ended."
    LANG[CLI_FAILED]="CLI failed to start."

    LANG[PORT_8443_TITLE]="Emergency Panel Access"
    LANG[PORT_8443_OPEN_OPT]="Open port 8443 (bypasses cookie auth)"
    LANG[PORT_8443_CLOSE_OPT]="Close port 8443"
    LANG[PORT_8443_IN_USE]="Port 8443 is already in use by another process."
    LANG[PORT_8443_WARNING]="Close this port when done! Panel is exposed without cookie protection."
    LANG[PORT_8443_CLOSED]="Port 8443 closed and firewall rule removed."
    LANG[PORT_8443_NOT_OPEN]="Port 8443 was not open."
    LANG[PORT_8443_ALREADY_CLOSED]="Firewall rule for port 8443 already removed."
    LANG[NGINX_CONF_PARSE_FAIL]="Could not read panel domain from nginx.conf."
    LANG[NGINX_MODIFY_FAIL]="Failed to modify nginx.conf."
    LANG[EMERGENCY_LINK]="Emergency link:"

    LANG[CERT_MENU_TITLE]="Manage SSL Certificates"
    LANG[CERT_RENEW]="Renew expiring certificates"
    LANG[CERT_NEW]="Generate certificate for new domain"
    LANG[CERT_DOMAIN_PROMPT]="Domain for new certificate"
    LANG[CERT_METHOD_CHOOSE]="Method [1/2]"
    LANG[CERT_NEW_OK]="Certificate generated successfully."
    LANG[CERT_RESULTS]="Renewal results:"
    LANG[DAYS_LEFT]="days remaining"
    LANG[RENEWED]="Renewed"
    LANG[RENEW_SKIPPED]="Skipped (more than 30 days left):"
    LANG[RENEW_FAILED]="Renewal failed:"
    LANG[CERT_EXPIRY_ERROR]="Could not read certificate expiry."

    LANG[IPV6_TITLE]="Manage IPv6"
    LANG[IPV6_ENABLE_OPT]="Enable IPv6"
    LANG[IPV6_DISABLE_OPT]="Disable IPv6"
    LANG[IPV6_ENABLED]="IPv6 enabled."
    LANG[IPV6_DISABLED]="IPv6 disabled."
    LANG[IPV6_ALREADY_ON]="IPv6 is already enabled."
    LANG[IPV6_ALREADY_OFF]="IPv6 is already disabled."
}

load_lang_ru() {
    LANG[LANG_SELECT]="Select language / Выберите язык:"
    LANG[LANG_EN]="English"
    LANG[LANG_RU]="Русский"
    LANG[ERROR_ROOT]="Скрипт должен быть запущен от root."
    LANG[ERROR_OS]="Неподдерживаемая ОС. Поддерживаются: Debian 11/12, Ubuntu 22/24."
    LANG[EXIT]="Отменено."
    LANG[INVALID_CHOICE]="Неверный выбор."
    LANG[CONFIRM_PROMPT]="Продолжить всё равно? [y/N]: "

    LANG[MENU_TITLE]="Установщик Remnawave"
    LANG[MENU_1]="Установить панель"
    LANG[MENU_2]="Установить ноду"
    LANG[MENU_3]="Добавить ноду к существующей панели"
    LANG[MENU_4]="Управление сервисами"
    LANG[MENU_5]="Управление SSL-сертификатами"
    LANG[MENU_6]="Управление IPv6"
    LANG[MENU_0]="Выход"
    LANG[PROMPT_ACTION]="Выберите опцию"

    LANG[ENTER_PANEL_DOMAIN]="Домен панели (напр. panel.example.com)"
    LANG[ENTER_SUB_DOMAIN]="Домен подписок (напр. sub.example.com)"
    LANG[ENTER_SELFSTEAL_DOMAIN]="Домен SelfSteal — камуфляжный сайт (напр. steal.example.com)"
    LANG[DOMAINS_MUST_BE_UNIQUE]="Все три домена должны отличаться."
    LANG[WARNING_LABEL]="ВНИМАНИЕ:"
    LANG[CHECK_DOMAIN_IP_FAIL]="Не удалось проверить DNS домена. Убедитесь, что A-запись существует."
    LANG[CHECK_DOMAIN_MISMATCH]="Домен %s указывает на %s, а IP этого сервера %s."
    LANG[CHECK_DOMAIN_MISMATCH_INSTRUCTION]="Убедитесь, что DNS A-запись указывает на этот сервер."
    LANG[CHECK_DOMAIN_CLOUDFLARE]="Домен %s проксируется через Cloudflare (%s). Это сломает XRAY Reality!"
    LANG[CHECK_DOMAIN_CLOUDFLARE_INSTRUCTION]="Отключите Cloudflare-прокси (серое облако) для доменов ноды/selfsteal."

    LANG[CERT_METHOD_PROMPT]="Способ получения SSL-сертификата:"
    LANG[CERT_METHOD_CF]="Cloudflare DNS-01 (wildcard, рекомендуется)"
    LANG[CERT_METHOD_ACME]="ACME HTTP-01 (standalone, для каждого домена)"
    LANG[EMAIL_PROMPT]="Email для уведомлений Let's Encrypt"
    LANG[ENTER_CF_TOKEN]="Cloudflare API Token (или Global Key)"
    LANG[ENTER_CF_EMAIL]="Email аккаунта Cloudflare (только для Global Key)"
    LANG[CF_VALIDATING]="Данные Cloudflare проверены."
    LANG[CF_INVALID_ATTEMPT]="Неверные данные (попытка %s/%s). Попробуйте снова."
    LANG[CF_INVALID]="Проверка Cloudflare не прошла после %s попыток."
    LANG[GENERATING_CERTS]="Генерируем SSL-сертификат для %s..."
    LANG[CERT_FOUND]="Сертификат найден: "
    LANG[WILDCARD_CERT_FOUND]="Wildcard-сертификат найден: "
    LANG[FOR_DOMAIN]="покрывает домен"
    LANG[CERT_NOT_FOUND]="Сертификат не найден для"
    LANG[CERTS_SKIPPED]="Сертификаты уже существуют, пропускаем генерацию."
    LANG[CERT_GENERATION_FAILED]="Ошибка генерации сертификата для"
    LANG[ADDING_CRON]="Добавляем еженедельное обновление certbot в cron..."

    LANG[INSTALL_PACKAGES]="Устанавливаем необходимые пакеты (Docker, certbot, ufw, jq...)..."
    LANG[SUCCESS_INSTALL]="Все пакеты успешно установлены."
    LANG[ERROR_INSTALL_PACKAGES]="Ошибка установки пакетов."
    LANG[ERROR_INSTALL_DOCKER]="Ошибка установки Docker."

    LANG[SUMMARY_TITLE]="===== Параметры установки ====="
    LANG[SUMMARY_CONFIRM]="Начать установку с этими параметрами? [y/N]"

    LANG[STARTING_PANEL]="Запускаем Docker-контейнеры..."
    LANG[WAITING]="Пожалуйста, подождите..."
    LANG[REGISTERING_REMNAWAVE]="Ожидаем готовности Remnawave API..."
    LANG[CHECK_CONTAINERS]="Проверяем состояние контейнеров..."
    LANG[CONTAINERS_NOT_READY_ATTEMPT]="Контейнеры не готовы (попытка %s/%s), повтор через 60с..."
    LANG[CONTAINERS_TIMEOUT]="Контейнеры не запустились после %s попыток. Проверьте: docker compose logs"
    LANG[REGISTRATION_SUCCESS]="Суперадмин зарегистрирован."
    LANG[GENERATE_KEYS]="Генерируем x25519 ключи XRAY..."
    LANG[GENERATE_KEYS_SUCCESS]="Ключи сгенерированы."
    LANG[CREATING_CONFIG_PROFILE]="Создаём профиль конфигурации XRAY..."
    LANG[CONFIG_PROFILE_CREATED]="Профиль конфигурации создан."
    LANG[CREATING_NODE]="Создаём запись ноды в панели..."
    LANG[NODE_CREATED]="Запись ноды создана."
    LANG[CREATE_HOST]="Создаём запись хоста..."
    LANG[HOST_CREATED]="Хост создан."
    LANG[GET_DEFAULT_SQUAD]="Получаем список отрядов..."
    LANG[UPDATE_SQUAD]="Отряд обновлён новым inbound."
    LANG[CREATING_API_TOKEN]="Создаём API-токен для страницы подписки..."
    LANG[API_TOKEN_ADDED]="API-токен создан и внедрён."
    LANG[STOPPING_SUB_PAGE]="Перезапускаем контейнер страницы подписки..."
    LANG[INSTALL_COMPLETE]="Установка завершена!"
    LANG[PANEL_ACCESS]="URL панели (сохраните в закладки):"
    LANG[ADMIN_CREDS]="Данные администратора:"
    LANG[USERNAME]="  Логин:    "
    LANG[PASSWORD]="  Пароль:   "
    LANG[RELAUNCH_CMD]="Для управления запустите:"

    LANG[ENTER_PANEL_IP]="IP-адрес сервера с панелью"
    LANG[IP_ERROR]="Неверный IPv4-адрес. Попробуйте снова."
    LANG[ENTER_PUBLIC_KEY]="Public Key из панели (Панель → Ноды → Public Key)"
    LANG[STARTING_NODE]="Запускаем контейнеры ноды..."
    LANG[NODE_LAUNCHED]="Нода отвечает по HTTPS."
    LANG[NODE_CHECK]="Проверяем HTTPS ноды на %s..."
    LANG[NODE_ATTEMPT]="Попытка %s из %s..."
    LANG[NODE_UNAVAILABLE]="Ещё не отвечает (попытка %s). Повтор через 15с..."
    LANG[NODE_NOT_CONNECTED]="Нода не ответила после %s попыток."
    LANG[CHECK_CONFIG]="Отладка: cd /opt/remnanode && docker compose logs -f"
    LANG[NODE_INSTALL_COMPLETE]="Установка ноды завершена!"
    LANG[NODE_HINT]="Нода слушает порт 2222 для подключения от панели."

    LANG[WARNING_NODE_PANEL]="Этот режим обращается к 127.0.0.1:3000 — запускайте на сервере ПАНЕЛИ."
    LANG[CONFIRM_SERVER_PANEL]="Вы на сервере панели? [y/N]"
    LANG[ADD_NODE_TO_PANEL]="Добавляем конфигурацию ноды в панель..."
    LANG[ENTER_NODE_DOMAIN]="Домен ноды (напр. node1.example.com)"
    LANG[ENTER_NODE_NAME]="Имя ноды (3-20 символов, буквы/цифры/дефис)"
    LANG[TRY_ANOTHER_DOMAIN]="Домен уже зарегистрирован в панели. Выберите другой."
    LANG[CF_INVALID_NAME]="Имя '%s' уже существует. Выберите другое."
    LANG[CF_INVALID_LENGTH]="Имя должно содержать 3-20 символов."
    LANG[CF_INVALID_CHARS]="Имя может содержать только буквы, цифры и дефисы."
    LANG[NODE_ADDED_SUCCESS]="Конфигурация ноды добавлена в панель."
    LANG[POST_PANEL_INSTRUCTION]="Следующий шаг: установите ноду на сервере ноды через опцию 2."

    LANG[ERROR_TOKEN]="Не удалось получить токен аутентификации."
    LANG[USING_SAVED_TOKEN]="Используем сохранённый токен..."
    LANG[INVALID_SAVED_TOKEN]="Сохранённый токен недействителен или истёк."
    LANG[TOKEN_RECEIVED_AND_SAVED]="Токен сохранён."
    LANG[TOKEN_USED_SUCCESSFULLY]="Токен действителен."
    LANG[ENTER_PANEL_USERNAME]="Логин администратора панели"
    LANG[ENTER_PANEL_PASSWORD]="Пароль администратора панели"
    LANG[NO_SQUADS_TO_UPDATE]="Отряды для обновления не найдены."
    LANG[UPDATING_SQUAD]="Обновляем отряд:"
    LANG[ERROR_UPDATE_SQUAD]="Ошибка обновления отряда:"
    LANG[ERROR_GET_SQUAD_LIST]="Ошибка получения списка отрядов."
    LANG[DOMAIN_ALREADY_EXISTS]="Домен уже существует в панели:"
    LANG[ERROR_CHECK_DOMAIN]="Ошибка проверки домена:"
    LANG[ERROR_GENERATE_KEYS]="Ошибка генерации ключей XRAY."
    LANG[ERROR_EXTRACT_PRIVATE_KEY]="Не удалось извлечь приватный ключ из ответа API."
    LANG[ERROR_CREATE_CONFIG_PROFILE]="Ошибка создания профиля конфигурации:"
    LANG[ERROR_EMPTY_RESPONSE_NODE]="Пустой ответ API (создание ноды)."
    LANG[ERROR_CREATE_NODE]="Ошибка создания ноды."
    LANG[ERROR_EMPTY_RESPONSE_HOST]="Пустой ответ API (создание хоста)."
    LANG[ERROR_CREATE_HOST]="Ошибка создания хоста."
    LANG[ERROR_GET_SQUAD]="Ошибка получения отрядов:"
    LANG[NO_SQUADS_FOUND]="Отряды не найдены."
    LANG[INVALID_UUID_FORMAT]="Неверный формат UUID:"
    LANG[NO_VALID_SQUADS_FOUND]="Нет корректных UUID отрядов."
    LANG[INVALID_SQUAD_UUID]="Неверный UUID отряда:"
    LANG[INVALID_INBOUND_UUID]="Неверный UUID inbound:"
    LANG[ERROR_CREATE_API_TOKEN]="Ошибка создания API-токена:"
    LANG[ERROR_PUBLIC_KEY]="Ошибка получения публичного ключа с панели."
    LANG[ERROR_EXTRACT_PUBLIC_KEY]="Не удалось извлечь публичный ключ из ответа."
    LANG[PUBLIC_KEY_SUCCESS]="Публичный ключ установлен в конфигурацию ноды."
    LANG[ERROR_EMPTY_RESPONSE_REGISTER]="Пустой ответ API при регистрации."
    LANG[ERROR_REGISTER]="Ошибка регистрации:"
    LANG[NO_DEFAULT_PROFILE]="Default-Profile не найден (уже удалён)."
    LANG[ERROR_NO_CONFIGS]="Ошибка получения профилей конфигурации."
    LANG[ERROR_DELETE_PROFILE]="Ошибка удаления Default-Profile."

    LANG[MANAGE_TITLE]="Управление сервисами"
    LANG[MANAGE_1]="Запустить сервисы"
    LANG[MANAGE_2]="Остановить сервисы"
    LANG[MANAGE_3]="Обновить Docker-образы"
    LANG[MANAGE_4]="Просмотр логов (Ctrl+C для выхода)"
    LANG[MANAGE_5]="Remnawave CLI"
    LANG[MANAGE_6]="Открыть/закрыть экстренный порт 8443"
    LANG[PANEL_RUNNING]="Сервисы уже запущены."
    LANG[PANEL_STOPPED]="Сервисы уже остановлены."
    LANG[STARTING_SERVICES]="Запускаем сервисы..."
    LANG[STOPPING_SERVICES]="Останавливаем сервисы..."
    LANG[SERVICES_STARTED]="Сервисы запущены."
    LANG[SERVICES_STOPPED]="Сервисы остановлены."
    LANG[UPDATING_IMAGES]="Загружаем последние образы..."
    LANG[NEW_IMAGES]="Обнаружены новые образы. Перезапускаем сервисы..."
    LANG[UPDATE_DONE]="Обновление завершено."
    LANG[ALREADY_LATEST]="Все образы актуальны."
    LANG[DIR_NOT_FOUND]="Установка не найдена в /opt/remnawave или /opt/remnanode."
    LANG[CONTAINER_NOT_RUNNING]="Контейнер 'remnawave' не запущен."
    LANG[RUNNING_CLI]="Запускаем Remnawave CLI..."
    LANG[CLI_DONE]="Сессия CLI завершена."
    LANG[CLI_FAILED]="Не удалось запустить CLI."

    LANG[PORT_8443_TITLE]="Экстренный доступ к панели"
    LANG[PORT_8443_OPEN_OPT]="Открыть порт 8443 (обход cookie-защиты)"
    LANG[PORT_8443_CLOSE_OPT]="Закрыть порт 8443"
    LANG[PORT_8443_IN_USE]="Порт 8443 уже занят другим процессом."
    LANG[PORT_8443_WARNING]="Закройте порт после использования! Панель будет открыта без cookie-защиты."
    LANG[PORT_8443_CLOSED]="Порт 8443 закрыт, правило UFW удалено."
    LANG[PORT_8443_NOT_OPEN]="Порт 8443 не был открыт."
    LANG[PORT_8443_ALREADY_CLOSED]="Правило UFW для порта 8443 уже удалено."
    LANG[NGINX_CONF_PARSE_FAIL]="Не удалось определить домен панели из nginx.conf."
    LANG[NGINX_MODIFY_FAIL]="Ошибка изменения nginx.conf."
    LANG[EMERGENCY_LINK]="Экстренная ссылка:"

    LANG[CERT_MENU_TITLE]="Управление SSL-сертификатами"
    LANG[CERT_RENEW]="Обновить истекающие сертификаты"
    LANG[CERT_NEW]="Сгенерировать сертификат для нового домена"
    LANG[CERT_DOMAIN_PROMPT]="Домен для нового сертификата"
    LANG[CERT_METHOD_CHOOSE]="Метод [1/2]"
    LANG[CERT_NEW_OK]="Сертификат успешно создан."
    LANG[CERT_RESULTS]="Результаты обновления:"
    LANG[DAYS_LEFT]="дней осталось"
    LANG[RENEWED]="Обновлён"
    LANG[RENEW_SKIPPED]="Пропущен (более 30 дней):"
    LANG[RENEW_FAILED]="Ошибка обновления:"
    LANG[CERT_EXPIRY_ERROR]="Не удалось прочитать срок действия сертификата."

    LANG[IPV6_TITLE]="Управление IPv6"
    LANG[IPV6_ENABLE_OPT]="Включить IPv6"
    LANG[IPV6_DISABLE_OPT]="Отключить IPv6"
    LANG[IPV6_ENABLED]="IPv6 включён."
    LANG[IPV6_DISABLED]="IPv6 отключён."
    LANG[IPV6_ALREADY_ON]="IPv6 уже включён."
    LANG[IPV6_ALREADY_OFF]="IPv6 уже отключён."
}

spinner() {
    local pid=$1 text=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    printf "${COLOR_GREEN}%s${COLOR_RESET}" "$text" > /dev/tty
    while kill -0 "$pid" 2>/dev/null; do
        for (( i=0; i<${#spinstr}; i++ )); do
            printf "\r${COLOR_GREEN}[%s] %s${COLOR_RESET}" "${spinstr:$i:1}" "$text" > /dev/tty
            sleep 0.1
        done
    done
    printf "\r\033[K" > /dev/tty
}

question() { echo -e "${COLOR_GREEN}[?]${COLOR_RESET} ${COLOR_YELLOW}$*${COLOR_RESET}"; }
reading()  { read -rp " $(question "$1")" "$2"; }
info()     { echo -e "${COLOR_YELLOW}[·]${COLOR_RESET} $*"; }
ok()       { echo -e "${COLOR_GREEN}[✓]${COLOR_RESET} $*"; }
error()    { echo -e "${COLOR_RED}[✗]${COLOR_RESET} $*"; exit 1; }
warn()     { echo -e "${COLOR_RED}[!]${COLOR_RESET} $*"; }

generate_user() {
    tr -dc 'a-zA-Z' < /dev/urandom | fold -w 8 | head -n 1
}

generate_password() {
    local pw=""
    pw+=$(tr -dc 'A-Z'             < /dev/urandom | head -c 1)
    pw+=$(tr -dc 'a-z'             < /dev/urandom | head -c 1)
    pw+=$(tr -dc '0-9'             < /dev/urandom | head -c 1)
    pw+=$(tr -dc '!@#%^&*()_+'    < /dev/urandom | head -c 3)
    pw+=$(tr -dc 'A-Za-z0-9!@#%^&*()_+' < /dev/urandom | head -c 18)
    echo "$pw" | fold -w1 | shuf | tr -d '\n'
}

extract_domain() {
    echo "$1" | awk -F'.' '{if (NF > 2) {print $(NF-1)"."$NF} else {print $0}}'
}

check_domain() {
    local domain="$1"
    local allow_cf="${2:-true}"

    local domain_ip server_ip
    domain_ip=$(dig +short A "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)
    server_ip=$(curl -s -4 --max-time 5 ifconfig.me 2>/dev/null \
             || curl -s -4 --max-time 5 api.ipify.org 2>/dev/null)

    if [ -z "$domain_ip" ] || [ -z "$server_ip" ]; then
        warn "${LANG[CHECK_DOMAIN_IP_FAIL]}"
        reading "${LANG[CONFIRM_PROMPT]}" _c
        [[ "$_c" != "y" && "$_c" != "Y" ]] && return 2
        return 1
    fi

    [ "$domain_ip" = "$server_ip" ] && return 0

    local cf_ranges
    cf_ranges=$(curl -s --max-time 5 https://www.cloudflare.com/ips-v4 2>/dev/null)
    if [ -n "$cf_ranges" ]; then
        local IFS_bak=$IFS; IFS=$'\n'; local cf_array=($cf_ranges); IFS=$IFS_bak
        local a b c d
        IFS='.' read -r a b c d <<< "$domain_ip"
        local dip=$(( (a<<24)+(b<<16)+(c<<8)+d ))
        for cidr in "${cf_array[@]}"; do
            [[ -z "$cidr" ]] && continue
            local net="${cidr%/*}" mask="${cidr#*/}"
            IFS='.' read -r a b c d <<< "$net"
            local nip=$(( (a<<24)+(b<<16)+(c<<8)+d ))
            local rng=$(( 1 << (32-mask) ))
            if (( dip >= nip && dip <= nip+rng-1 )); then
                if [ "$allow_cf" = true ]; then return 0; fi
                warn "$(printf "${LANG[CHECK_DOMAIN_CLOUDFLARE]}" "$domain" "$domain_ip")"
                warn "${LANG[CHECK_DOMAIN_CLOUDFLARE_INSTRUCTION]}"
                reading "${LANG[CONFIRM_PROMPT]}" _c
                [[ "$_c" == "y" || "$_c" == "Y" ]] && return 1
                return 2
            fi
        done
    fi

    warn "$(printf "${LANG[CHECK_DOMAIN_MISMATCH]}" "$domain" "$domain_ip" "$server_ip")"
    warn "${LANG[CHECK_DOMAIN_MISMATCH_INSTRUCTION]}"
    reading "${LANG[CONFIRM_PROMPT]}" _c
    [[ "$_c" == "y" || "$_c" == "Y" ]] && return 1
    return 2
}

check_root() { [[ $EUID -ne 0 ]] && error "${LANG[ERROR_ROOT]}"; }

check_os() {
    grep -qE "bullseye|bookworm|jammy|noble|trixie" /etc/os-release 2>/dev/null \
        || error "${LANG[ERROR_OS]}"
}

add_cron_rule() {
    local rule="$1"
    crontab -u root -l 2>/dev/null | grep -Fq "$rule" && return
    (crontab -u root -l 2>/dev/null; echo "$rule") | crontab -u root -
}

is_wildcard_cert() {
    local domain="$1"
    local cert="/etc/letsencrypt/live/$domain/fullchain.pem"
    [ -f "$cert" ] && openssl x509 -noout -text -in "$cert" 2>/dev/null | grep -q "\*\.$domain"
}
