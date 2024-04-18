#!/bin/bash

#---------------------------------------------------------Підготовка до виконання скрипту#---------------------------------------------------------

clear
system_ready=true
> best_proxy.txt
> ping_results.txt
> proxy_list.txt
nmap_errors=$(mktemp)

# Перевірка доступу до Інтернету
echo -n "Перевірка інтернет з'єднання..."
timeout=3
if curl --connect-timeout ${timeout} -s -o /dev/null https://www.krea.ai/; then
    echo -e " - [  \033[32mOK\033[0m  ]\n "
    internet=true
else
    echo -e " - [  \033[31mNO\033[0m  ]\n "
    internet=false
    system_ready=false
    echo -n "Бажаєте завершити роботу скрипта? (Y/n): "
    read -n 1 answer
    echo
    if [[ $answer =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Перевірка доступу до ресурсу проксі серверів
echo -n "Перевірка з'єднання з ресурсом проксі серверів..."
timeout=3

if curl --connect-timeout ${timeout} -s -o /dev/null https://api.proxyscrape.com; then
    echo -e " - [  \033[32mOK\033[0m  ]\n "
    proxylist=true
else
    echo -e " - [  \033[31mNO\033[0m  ]\n "
    proxylist=false
    system_ready=false
    echo -n "Бажаєте завершити роботу скрипта? (Y/n): "
    read -n 1 answer
    echo
    if [[ $answer =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi


echo "Перевірка MAC адреси..."
macchanger -s wlo1

# Список необхідних програм
programs=(curl wget nmap macchanger proxychains)


# Перевірка наявності програм
for program in "${programs[@]}"; do
    if ! which "$program" > /dev/null; then
        echo "Програма \"$program\" не знайдена."
        missing_programs=true
    else 
        programshave=true
    fi

done

# Якщо програми не знайдені, запропонувати користувачу завантажити їх
if [[ $missing_programs ]]; then
    echo "Чи бажаєте ви завантажити необхідні програми? (Y/n)"
    read -n 1 answer
    echo

    if [[ $answer =~ ^[Yy]$ ]]; then
        # Команди для завантаження програм
        sudo apt install curl wget nmap macchanger tsocks -y

        # Перевірте, чи всі програми успішно завантажені
        for program in "${programs[@]}"; do
            if ! which "$program" > /dev/null; then
                echo "Не вдалося завантажити програму \"$program\". Спробуйте завантажити її вручну за допомогою sudo apt-get install \"$program\" "
                exit 1
            fi
        done
    else
        echo -e "\033[31mСкрипт не може бути виконаний без необхідних програм.\033[0m"
        exit 1
    fi
fi



if [ "$internet" == "false" ]; then
    echo -e " "
    echo -e "Скрипт не зможе продовжити роботу через відсутність інтернету."
fi


if [ "$proxylist" == "false" ]; then
    echo -e "Скрипт не зможе продовжити роботу через відсутність проксі серверів у списку."
fi


if [ "$programshave" == "true" ]; then
    echo " "
    echo -e "\033[32mВсі необхідні програми присутні на пристрої.\033[0m"
fi


if [ "$system_ready" == "true" ]; then
    echo -e "\033[32mПеревірка системи успішна, аналізуємо проксі.\033[0m"
    echo -e " "
    # ...
else
    echo -e "\033[31mПеревірка системи не вдалася.\033[0m"
    exit 1
fi



#---------------------------------------------------------Виконання скрипту---------------------------------------------------------



# Додаємо команду trap, щоб зупинити всі дочірні процеси при завершенні головного процесу
trap 'kill $(jobs -p) 2>/dev/null; stty sane' EXIT SIGINT SIGTERM

# Початок безкінечного циклу
while true; do
    # Етап 1: Завантаження списку проксі серверів з Інтернету
    if ! curl -s "https://api.proxyscrape.com/?request=getproxies&proxytype=socks5&timeout=10000&ssl=yes" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]+' | tr '\0' '\n' > proxy_list.txt; then
        echo -e "\\033[31mНе вдалося завантажити список проксі. Вихід.\\033[0m"
        exit 1
    fi

    # Етап 2: Перевірка якості зв'язку з кожним сервером
    cat proxy_list.txt | xargs -n1 -P 10 -I {} bash -c '
    proxy={}
    # Перевірка формату проксі
    if [[ "$proxy" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]+$ ]]; then
        proxy_ip="${BASH_REMATCH[1]%:*}"
        proxy_port="${BASH_REMATCH[1]##*:}"

        # Перевірка типу проксі (SOCKS5)
        if nc -zvw5 "$proxy_ip" "$proxy_port" > /dev/null 2>&1; then
            # Перевірка затримки зєднання
            start_time=$(date +%s%N)
            if curl --max-time 10 --proxy "socks5://$proxy_ip:$proxy_port" http://example.com > /dev/null 2>&1; then
                end_time=$(date +%s%N)
                elapsed_time=$(( (end_time - start_time) / 1000000 ))
                echo "$proxy $elapsed_time" >> ping_results.txt
                echo -e "Сервер: \\033[32m$proxy\\033[0m"   
                echo -e "Пінг: \\033[33m$elapsed_time(ms)\\033[0m"
                echo " "
            else
                echo -e "Сервер: \\033[31m$proxy\\033[0m"
                echo -e "не пройшов перевірку"
                echo " "
            fi
        else
            echo " Пропускаємо, проксі $proxy не є SOCKS5."
        fi
    else
        echo " Пропускаємо, неправильний формат проксі $proxy."
    fi
' || true

    
    # Етап 3: Вибір проксі сервера з найкращим зв'язком
    best_proxy=$(sort -n -k 2 ping_results.txt | head -n 1 | awk '{print $1}')

    # Запис найкращого проксі в файл best_proxy.txt
    echo "$best_proxy" > best_proxy.txt
    formatted_proxy=${best_proxy//:/ }

    # Етап 4: Підключення користувача до обраного проксі сервера
    best_proxy=$(sort -n -k 2 ping_results.txt | head -n 1 | awk '{print $1}')
    proxy_ip=$(echo "$best_proxy" | cut -d':' -f1)
    proxy_port=$(echo "$best_proxy" | cut -d':' -f2)

    # Перевірка, чи змінна best_proxy не порожня
    if [ -n "$best_proxy" ]; then
        echo -e "Запускаємо Firefox з використанням проксі"
        echo -e "$best_proxy..."
        firefox_pid=$(/usr/bin/firefox --proxy-server="socks5://$proxy_ip:$proxy_port" --no-proxy-server-bypasslist & 2>&1 | grep -o -E '[0-9]+')
    else
        echo "Не вдалось підключитися до проксі."
        exit 1
    fi



    # Етап 5: Перевірка успішності підключення
    sleep 5 # Дати Firefox трохи часу на запуск
    if curl -x "socks5://$best_proxy" --max-time 5 http://google.com > /dev/null 2>&1; then
        echo "Успішно підключено до $best_proxy"
    else
        echo "Не вдалося підключитися до $best_proxy"
        echo "Вихід."
        exit 1
    fi


    # Етап 6: Виведення інформації про пінг кожні 5 секунд та переключення проксі кожні 10 хвилин
    while true; do
        start_time=$(date +%s%N)
        if curl -x "socks5://$best_proxy" --max-time 5 http://google.com > /dev/null 2>&1; then
            end_time=$(date +%s%N)
            elapsed_time=$(( (end_time - start_time) / 1000000 ))
            echo "Пінг: $elapsed_time мс"
        fi
        sleep 5

        # Перевірка, чи минуло 10 хвилин (600 секунд)
        if [ "$(($(date +%s) - start_time / 1000000000))" -ge 600 ]; then
            echo "Переключаємось на новий проксі..."

            # Закриваємо Firefox
            kill "$firefox_pid"

            # Вибираємо новий проксі та запускаємо Firefox
            new_proxy=$(sort -n -k 2 ping_results.txt | head -n 1 | awk '{print $1}')
            new_proxy_ip=$(echo "$new_proxy" | cut -d':' -f1)
            new_proxy_port=$(echo "$new_proxy" | cut -d':' -f2)
            firefox_pid=$((/usr/bin/firefox --proxy-server="socks5://$new_proxy_ip:$new_proxy_port" --no-proxy-server-bypasslist &) 2>&1 | grep -o -E '[0-9]+')

            echo "Успішно переключено на новий проксі $new_proxy"
            best_proxy="$new_proxy"
        fi
    done
#     # Етап 7: Перевірка часу після підключення та повторний пошук проксі сервера через 10 хвилин
#     sleep 600
#     echo "Перепідключення до проксі-сервера..."

#     # Етап 8: Повторний вибір проксі сервера та підключення
#     new_proxy=$(sort -n -k 2 ping_results.txt | head -n 1 | awk '{print $1}')
#     unset http_proxy
#     unset https_proxy
#     export http_proxy="http://$new_proxy"
#     export https_proxy="http://$new_proxy"
    
#     # Етап 9: Повідомлення про перепідключення
#     echo "Успішно перепідключено до $new_proxy"
#     # Етап 10: Відключення від проксі сервера
#     unset http_proxy
#     unset https_proxy
 done
