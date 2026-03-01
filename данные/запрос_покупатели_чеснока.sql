-- ============================================================
-- ЗАПРОС: Кто через Сармант ввозит ЧЕСНОК из Китая?
-- Запустить на рабочем компе через pgAdmin или psql
-- ============================================================

-- 1. ТОП компаний-импортёров чеснока (через цепочку ДТ → заказ → клиент/принципал)
SELECT
    COALESCE(lc_princ.list_company_name, lc_client.list_company_name) AS "Компания (принципал)",
    COALESCE(lc_princ.inn, lc_client.inn) AS "ИНН",
    lc_client.list_company_name AS "Клиент (импортёр)",
    COUNT(DISTINCT lg.id) AS "Кол-во ДТ",
    ROUND(SUM(fg.net_weight)::numeric / 1000, 1) AS "Тонн нетто",
    ROUND(AVG(fg.price_one_kg)::numeric, 2) AS "Ср. тамож. $/кг",
    MIN((lg.date_clear + interval '3 hour')::date) AS "Первая ДТ",
    MAX((lg.date_clear + interval '3 hour')::date) AS "Последняя ДТ"
FROM public.list_feacc_gtd fg
    JOIN public.list_gtd lg ON fg.id_list_gtd = lg.id
    LEFT JOIN declaration.unit dec_unit ON dec_unit.id_list_gtd = lg.id
    LEFT JOIN declaration.dec_unit_oper_unit_link link ON link.id_declaration_unit = dec_unit.id
    LEFT JOIN operation.unit op_unit ON link.id_operation_unit = op_unit.id
    LEFT JOIN public.order ord ON op_unit.id_order = ord.id
    LEFT JOIN public.list_company lc_client ON ord.id_company_client = lc_client.id
    LEFT JOIN public.list_company lc_princ ON COALESCE(NULLIF(ord.id_company_principal, 0), ord.id_company_client) = lc_princ.id
WHERE fg.deleted = 0
    AND lg.deleted = 0
    AND fg.feacc_no LIKE '070320%'              -- Чеснок
    AND fg.origin_country_code = 'CN'            -- Из Китая
    AND lg.date_clear > '2023-01-01'
GROUP BY
    COALESCE(lc_princ.list_company_name, lc_client.list_company_name),
    COALESCE(lc_princ.inn, lc_client.inn),
    lc_client.list_company_name
ORDER BY "Тонн нетто" DESC
LIMIT 30;


-- 2. Помесячная динамика чеснока (кто сколько в каком месяце)
SELECT
    TO_CHAR(lg.date_clear + interval '3 hour', 'YYYY-MM') AS "Месяц",
    COALESCE(lc_princ.list_company_name, lc_client.list_company_name) AS "Компания",
    ROUND(SUM(fg.net_weight)::numeric / 1000, 1) AS "Тонн",
    COUNT(DISTINCT lg.id) AS "ДТ",
    ROUND(AVG(fg.price_one_kg)::numeric, 2) AS "Ср. $/кг"
FROM public.list_feacc_gtd fg
    JOIN public.list_gtd lg ON fg.id_list_gtd = lg.id
    LEFT JOIN declaration.unit dec_unit ON dec_unit.id_list_gtd = lg.id
    LEFT JOIN declaration.dec_unit_oper_unit_link link ON link.id_declaration_unit = dec_unit.id
    LEFT JOIN operation.unit op_unit ON link.id_operation_unit = op_unit.id
    LEFT JOIN public.order ord ON op_unit.id_order = ord.id
    LEFT JOIN public.list_company lc_client ON ord.id_company_client = lc_client.id
    LEFT JOIN public.list_company lc_princ ON COALESCE(NULLIF(ord.id_company_principal, 0), ord.id_company_client) = lc_princ.id
WHERE fg.deleted = 0
    AND lg.deleted = 0
    AND fg.feacc_no LIKE '070320%'
    AND fg.origin_country_code = 'CN'
    AND lg.date_clear > '2024-01-01'
GROUP BY "Месяц", "Компания"
ORDER BY "Месяц" DESC, "Тонн" DESC;


-- 3. Поставщики чеснока (кто в Китае отгружает)
SELECT
    lg.seller_name AS "Поставщик (Китай)",
    COUNT(DISTINCT lg.id) AS "ДТ",
    ROUND(SUM(fg.net_weight)::numeric / 1000, 1) AS "Тонн",
    ROUND(AVG(fg.price_one_kg)::numeric, 2) AS "Ср. $/кг",
    MIN((lg.date_clear + interval '3 hour')::date) AS "С",
    MAX((lg.date_clear + interval '3 hour')::date) AS "По"
FROM public.list_feacc_gtd fg
    JOIN public.list_gtd lg ON fg.id_list_gtd = lg.id
WHERE fg.deleted = 0
    AND lg.deleted = 0
    AND fg.feacc_no LIKE '070320%'
    AND fg.origin_country_code = 'CN'
    AND lg.date_clear > '2024-01-01'
GROUP BY lg.seller_name
ORDER BY "Тонн" DESC
LIMIT 20;
