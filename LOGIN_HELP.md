# 🔐 FreqUI Login Help

## Login Credentials

**Username**: `houssam`  
**Password**: `trading2025`

## If Login Still Fails

### 1. Check Freqtrade API Status
```cmd
cd C:\Users\houss\freqtrade
freqtrade_manager.bat status
```

Both containers should show "running":
- `houssam_freqtrade_redis`
- `houssam_freqtrade_bot`

### 2. Test API Connection
```cmd
curl http://localhost:8080/api/v1/ping
```

Should return: `{"status":"pong"}`

### 3. Check Logs for Errors
```cmd
cd C:\Users\houss\freqtrade
freqtrade_manager.bat logs
```

### 4. Restart Everything
```cmd
cd C:\Users\houss\freqtrade
freqtrade_manager.bat stop
freqtrade_manager.bat start
```

### 5. Update Login Credentials (Optional)

Edit `C:\Users\houss\freqtrade\user_data\config.json`:

```json
"api_server": {
  "username": "your_new_username",
  "password": "your_new_password"
}
```

Then restart: `freqtrade_manager.bat restart`

## FreqUI Access

1. **Start FreqUI**: `start_frequi.bat`
2. **Open Browser**: http://localhost:3000
3. **Login**: Use credentials above

---

*If you're still having issues, the API might not be fully started yet. Wait 30 seconds and try again.*
