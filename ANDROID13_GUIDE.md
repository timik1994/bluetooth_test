# Руководство по Android 13

## Проблемы с Bluetooth в Android 13

Android 13 (API 33) ввел новые ограничения и требования для Bluetooth приложений.

### 🔧 Основные изменения в Android 13:

#### 1. **Новые разрешения**
- `POST_NOTIFICATIONS` - для уведомлений
- `NEARBY_WIFI_DEVICES` - для поиска устройств поблизости
- Обновленные флаги для `BLUETOOTH_CONNECT` и `BLUETOOTH_SCAN`

#### 2. **Строгие требования к разрешениям**
- Все Bluetooth разрешения должны быть запрошены во время выполнения
- Разрешения на местоположение обязательны для сканирования
- Уведомления требуют явного разрешения

#### 3. **Ограничения безопасности**
- Более строгая проверка разрешений
- Ограничения на доступ к Bluetooth без разрешений
- Требования к targetSdkVersion

### 🛠️ Исправления в приложении:

#### 1. **Обновленный AndroidManifest.xml**
```xml
<!-- Android 13+ permissions -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />

<!-- Runtime permissions for Android 13+ -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" 
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" 
    android:usesPermissionFlags="neverForLocation" />
```

#### 2. **Обновленный build.gradle**
```gradle
defaultConfig {
    minSdkVersion 21
    targetSdkVersion 33  // Android 13
    // ...
}
```

#### 3. **Улучшенная обработка разрешений**
- Запрос всех необходимых разрешений
- Проверка статуса каждого разрешения
- Подробное логирование процесса

### 📱 Диагностика проблем:

#### 1. **Проверьте разрешения**
- Откройте приложение
- Нажмите "Запросить разрешения"
- Проверьте статус каждого разрешения

#### 2. **Проверьте логи**
- Смотрите сообщения в разделе "Логи"
- Ищите ошибки с разрешениями
- Проверьте статус Bluetooth

#### 3. **Частые ошибки Android 13:**

**"Permission denied"**
- Решение: Предоставьте все разрешения в настройках

**"Bluetooth scan failed"**
- Решение: Включите Bluetooth и местоположение

**"App not found"**
- Решение: Переустановите приложение

### 🔍 Пошаговая диагностика:

1. **Запустите приложение**
2. **Проверьте статус разрешений** - все должны быть "granted"
3. **Нажмите "Запросить разрешения"** если нужно
4. **Нажмите "Начать сканирование"**
5. **Проверьте логи** на наличие ошибок

### ⚠️ Важные замечания:

1. **Target SDK**: Установлен на 33 (Android 13)
2. **Разрешения**: Все необходимые разрешения добавлены
3. **Обработка ошибок**: Улучшена для Android 13
4. **Логирование**: Подробное для диагностики

### 🚀 Если проблемы остаются:

1. **Переустановите приложение**
2. **Очистите кэш приложения**
3. **Перезагрузите устройство**
4. **Проверьте настройки Android**

### 📋 Список разрешений для Android 13:

- ✅ `BLUETOOTH` - базовое Bluetooth
- ✅ `BLUETOOTH_ADMIN` - управление Bluetooth
- ✅ `BLUETOOTH_CONNECT` - подключение к устройствам
- ✅ `BLUETOOTH_SCAN` - сканирование устройств
- ✅ `ACCESS_FINE_LOCATION` - точное местоположение
- ✅ `ACCESS_COARSE_LOCATION` - приблизительное местоположение
- ✅ `POST_NOTIFICATIONS` - уведомления (Android 13+)
- ✅ `NEARBY_WIFI_DEVICES` - устройства поблизости (Android 13+)

Все разрешения должны быть предоставлены для корректной работы приложения на Android 13.
