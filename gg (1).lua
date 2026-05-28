--[[
  Auto-Updater for treningcaptchi
  by @krankmode -PIZDA EDITION-
  
  Скачивает последнюю версию с GitHub при запуске.
  Если ошибка - использует текущий файл.
]]

local script_name = "treningcaptchi (3).lua"
local github_raw_url = "https://raw.githubusercontent.com/decetequsub67-gif/SAMP-CHEAT/main/treningcaptchi%20(3).lua"
local moonloader_path = getWorkingDirectory()
local script_path = moonloader_path .. "\\" .. script_name
local temp_path = moonloader_path .. "\\treningcaptchi_temp.lua"

-- Простая функция скачивания через os.execute (curl)
local function download_with_curl()
    print("[UPDATER] Скачивание через curl...")
    
    -- Удаляем старый временный файл
    os.remove(temp_path)
    
    -- Скачиваем через curl
    local cmd = string.format(
        'curl -L -o "%s" "%s" 2>nul',
        temp_path,
        github_raw_url
    )
    
    local result = os.execute(cmd)
    
    -- Проверяем что файл создан и имеет размер
    local file = io.open(temp_path, "rb")
    if file then
        local size = file:seek("end")
        file:close()
        if size > 1000 then
            print("[UPDATER] Скачано: " .. size .. " байт")
            return true
        end
    end
    
    print("[UPDATER] Curl не сработал или файл пустой")
    os.remove(temp_path)
    return false
end

-- Альтернативная функция через LuaSocket
local function download_with_luasocket()
    print("[UPDATER] Пробуем LuaSocket...")
    
    local ok, http = pcall(require, "socket.http")
    if not ok then
        print("[UPDATER] LuaSocket не найден")
        return false
    end
    
    local ok2, ltn12 = pcall(require, "ltn12")
    if not ok2 then
        print("[UPDATER] LTN12 не найден")
        return false
    end
    
    http.TIMEOUT = 30
    
    local response = {}
    local res, code = http.request{
        url = github_raw_url,
        sink = ltn12.sink.table(response),
        method = "GET"
    }
    
    if code == 200 or code == true then
        local content = table.concat(response)
        if #content > 1000 then
            local file = io.open(temp_path, "wb")
            if file then
                file:write(content)
                file:close()
                print("[UPDATER] Скачано через LuaSocket: " .. #content .. " байт")
                return true
            end
        end
    end
    
    print("[UPDATER] LuaSocket вернул: " .. tostring(code))
    return false
end

-- Проверка валидности Lua файла
local function is_valid_lua(path)
    local file = io.open(path, "rb")
    if not file then return false end
    
    local content = file:read(500) -- читаем первые 500 байт
    file:close()
    
    if not content then return false end
    
    -- Ищем ключевые слова Lua
    if content:find("function") or content:find("local") or content:find("require") then
        return true
    end
    
    return false
end

-- Основная функция обновления
local function check_update()
    print("[UPDATER] Проверка обновлений...")
    
    -- Пробуем curl (надежнее)
    local success = download_with_curl()
    
    -- Если curl не сработал, пробуем LuaSocket
    if not success then
        success = download_with_luasocket()
    end
    
    if not success then
        print("[UPDATER] Не удалось скачать файл")
        return false
    end
    
    -- Проверяем валидность
    if not is_valid_lua(temp_path) then
        print("[UPDATER] Скачанный файл невалидный!")
        os.remove(temp_path)
        return false
    end
    
    -- Удаляем старый файл если есть
    local old_file = io.open(script_path, "rb")
    if old_file then
        old_file:close()
        os.remove(script_path)
    end
    
    -- Переименовываем
    if os.rename(temp_path, script_path) then
        print("[UPDATER] Файл обновлен!")
        return true
    else
        print("[UPDATER] Ошибка при переименовании")
        os.remove(temp_path)
        return false
    end
end

-- Основная функция
function main()
    print("")
    print("====================================")
    print("  KRANKMODE UPDATER - PIZDA EDITION")
    print("====================================")
    print("")
    
    -- Проверяем обновления
    check_update()
    
    -- Загружаем основной скрипт если существует
    local file = io.open(script_path, "rb")
    if file then
        file:close()
        print("[UPDATER] Загрузка: " .. script_name)
        
        local ok, err = pcall(dofile, script_path)
        
        if not ok then
            print("[UPDATER] Ошибка загрузки: " .. tostring(err))
        end
    else
        print("[UPDATER] Файл не найден: " .. script_path)
    end
    
    -- Ждем SAMPFUNCS если доступен
    local has_sf = pcall(function() return isSampfuncsAvailable end)
    
    if has_sf then
        while not isSampfuncsAvailable() do
            wait(100)
        end
        
        sampRegisterChatCommand("update", function()
            local updated = check_update()
            if updated then
                sampAddChatMessage("[UPDATER] Обновлено! Напиши /reload", 0x00FF00)
            else
                sampAddChatMessage("[UPDATER] Ошибка или уже актуально", 0xFFFF00)
            end
        end)
    end
    
    thisScript():unload()
end

print("[UPDATER] Инициализация...")
