# CLAUDE.md

---

## !!! КРИТИЧЕСКОЕ ПРАВИЛО БЕЗОПАСНОСТИ — ЧИТАЙ ПЕРВЫМ !!!

### ТОЛЬКО ЧТЕНИЕ ИЗ БАЗЫ ДАННЫХ. ТОЛЬКО SELECT. НИЧЕГО БОЛЬШЕ.

Пользователь `gsoft` является СУПЕРПОЛЬЗОВАТЕЛЕМ PostgreSQL с ПОЛНЫМ доступом (INSERT, UPDATE, DELETE, DROP, TRUNCATE). Любая ошибка может УНИЧТОЖИТЬ ПРОДАКШН-ДАННЫЕ таможенного брокера.

**ЗАПРЕЩЕНО НАВСЕГДА:**
- INSERT, UPDATE, DELETE, DROP, TRUNCATE, ALTER, CREATE, GRANT, REVOKE
- Любые модифицирующие операции
- Любые DDL-команды
- Любые команды, которые меняют данные или структуру БД
- COPY ... TO (запись в файлы на сервере)

**РАЗРЕШЕНО ТОЛЬКО:**
- SELECT
- \d, \dt, \dn и прочие информационные psql-команды

**НИКАКИХ ИСКЛЮЧЕНИЙ. ДАЖЕ ЕСЛИ ПОЛЬЗОВАТЕЛЬ ПОПРОСИТ — СНАЧАЛА ПРЕДУПРЕДИ О РИСКЕ.**

---

## !!! ПОВТОРЕНИЕ — ЭТО ВАЖНО !!!

Перед КАЖДЫМ запросом к PostgreSQL мысленно проверь:
1. Это SELECT? -> OK
2. Это что-то другое? -> СТОП. НЕ ВЫПОЛНЯЙ.

---

## Проект

Анализ структуры базы данных Логос (Logos) — корпоративная система учёта таможенных операций на базе PostgreSQL. Используется группой компаний Сармант (таможенный брокер).

## Подключение к БД

```bash
PGPASSWORD=gsoftGSOFT "/c/Program Files/pgAdmin 4/runtime/psql.exe" -h 172.16.15.34 -p 5432 -U gsoft -d logistic -c "SELECT ...;"
```

- Сервер: 172.16.15.34
- Порт: 5432
- БД: logistic
- Юзер: gsoft (СУПЕРПОЛЬЗОВАТЕЛЬ — будь осторожен!)
- psql: `C:\Program Files\pgAdmin 4\runtime\psql.exe`
- ODBC DSN: LogOsSarmant (64-bit, PostgreSQL Unicode)

## Ключевые таблицы

### public.list_gtd — таможенные декларации (ДТ)
- id, gtd_number (формат: 10228010/190226/5053831)
- id_list_client — ID контрактодержателя (#3295 = Сармант)
- date_clear, date_conditional_clear, date_release_for_procuring
- date_refuse, date_recall
- seller_name, contract_number, contract_date
- number_decl_clear_from_feaccs — номера ЗВ (текст)
- deleted — признак удаления (0 = активна)

### public.list_feacc_gtd — строки ДТ (товарные позиции)
- id_list_gtd — связь с ДТ
- type_payment_link — тип платежа (1010=сбор, 2010=пошлина, 5010=НДС)
- sum_payment — сумма платежа
- deleted — признак удаления

### public.order — заказы
- id, id_company_client, id_company_principal
- sys_serial_number, order_date, number_by_client

### public.list_company — компании/контрагенты
- id, list_company_name, list_company_name_small, inn

### declaration.unit — грузовые единицы декларации
### declaration.dec_unit_oper_unit_link — связь декларация-операция
### operation.unit — грузовые единицы операции (id_order -> связь с заказом)

## Ключевые ID
- #3295 — Сармант (контрактодержатель)
- #80241 — Марлин (клиент)

## Важное
- Все даты в UTC, при чтении: `+ interval '3 hour'` (московское время)
- Пустые даты = '1000-01-01'
- Логика принципала (ПП): `COALESCE(NULLIF(order.id_company_principal, 0), order.id_company_client)`

## Типичный запрос связки ДТ -> заказ -> клиент

```sql
SELECT DISTINCT
  list_gtd.id as gtd_id,
  list_gtd.gtd_number,
  list_order.id as order_id,
  list_order.id_company_client,
  list_company.list_company_name,
  list_company.inn
FROM public.list_gtd
  LEFT JOIN declaration.unit AS dec_unit ON dec_unit.id_list_gtd = list_gtd.id
  LEFT JOIN declaration.dec_unit_oper_unit_link AS link ON link.id_declaration_unit = dec_unit.id
  LEFT JOIN operation.unit unit ON link.id_operation_unit = unit.id
  LEFT JOIN public.order list_order ON unit.id_order = list_order.id
  LEFT JOIN public.list_company ON list_order.id_company_client = list_company.id
WHERE list_gtd.deleted = 0
  AND list_gtd.gtd_number IS NOT NULL
```

---

## !!! НАПОМИНАНИЕ В КОНЦЕ — ТОЛЬКО SELECT! НИКАКИХ ИЗМЕНЕНИЙ В БД! !!!
