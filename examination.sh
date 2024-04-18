#!/bin/bash

#---------------------------------------------------------Підготовка до виконання скрипту#---------------------------------------------------------
system_ready=true
> best_proxy.txt
> ping_results.txt
> proxy_list.txt
nmap_errors=$(mktemp)
# Перевірка доступу до Інтернету
echo -n "Перевірка інтернет з'єднання..."
timeout=3
if curl --connect-timeout ${timeout} -s -o /dev/null https://www.krea.ai/; then
    echo -e " - \033[32mOK\033[0m\n"
    internet=true
else
    echo -e " - \033[31mNO\033[0m\n"
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
    echo -e " - \033[32mOK\033[0m\n"
    proxylist=true
else
    echo -e " - \033[31mNO\033[0m\n"
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
        sudo apt install curl wget nmap macchanger proxychains -y

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
    # ...
fi

