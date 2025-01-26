/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Дарья
 * Дата: 24-10-2024
*/

-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Напишите ваш запрос здесь
-- Определяем аномальные значения
WITH
anomal AS (
	SELECT PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS anomal_total_area,
		PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS anomal_rooms,
		PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS anomal_balcony,
		PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS anomal_max_ceiling_height,
		PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS anomal_min_ceiling_height
	FROM real_estate.flats f 
),
-- Выводим таблицу flats, которая содержит нормальные значения, отличные от аномальных
new_flats AS (
    SELECT *
    FROM real_estate.flats  
    WHERE total_area < (SELECT anomal_total_area FROM anomal) 
        AND rooms < (SELECT anomal_rooms FROM anomal) 
        AND balcony < (SELECT anomal_balcony FROM anomal) 
        AND ceiling_height < (SELECT anomal_max_ceiling_height FROM anomal) 
        AND ceiling_height > (SELECT anomal_min_ceiling_height FROM anomal)
    ),
 -- разделяем данные на СПБ и ЛенОбл., а также готовим разделение данных по времени активности
flats_with_advertisements AS (
	SELECT CASE WHEN city = 'Санкт-Петербург'
				THEN 'Санкт-Петербург'
				ELSE 'Ленинградская область'
			END AS category_city, -- разделяем данные на СПБ и ЛенОбл.
			CASE WHEN days_exposition < 31
				THEN '1) месяц'
				WHEN days_exposition > 30 AND days_exposition < 91
				THEN '2) квартал'
				WHEN days_exposition > 90 AND days_exposition < 181
				THEN '3) полгода'
				ELSE '4) больше полугода' 
			END AS category_time, -- разделение дней активности объявления на периоды (месяц, квартал, полгода, больше полугода), нумерация нужна для корректной сортировки
			days_exposition,
			last_price,
			total_area,
			rooms,
			balcony,
			floor,
			city
	FROM new_flats 
	JOIN real_estate.advertisement a 
	USING(id)
	JOIN real_estate.city c 
	USING(city_id)
	WHERE days_exposition IS NOT NULL -- мы изучаем данные по времени активности объявления, поэтому нас интересуют именно снятая с продажи недвижимость, у которой ненулевое значение дней активности  
	)
	-- в основном запросе выводятся необходимые для анализа, данные, разделенные по времени активности объявления на сайте
SELECT category_city,
		category_time,
		COUNT(days_exposition) AS count_id, -- количество проданной недвижимости
		ROUND(AVG(last_price::real/total_area)::numeric, 2) AS avg_sqm, --средняя стоимость квадратного метра
		ROUND(AVG(total_area)::numeric)  AS avg_total_area, --средняя площадь недвижимости
		percentile_disc(0.5) WITHIN GROUP (ORDER BY rooms) AS med_rooms, --медиана кол-ва комнат или какое кол-во комнат встречается чаще всего
		percentile_disc(0.5) WITHIN GROUP (ORDER BY balcony) AS med_balcony,--медиана кол-ва балконов или какое кол-во балконов встречается чаще всего
		percentile_disc(0.5) WITHIN GROUP (ORDER BY floor) AS med_floor----медиана этажа квартиры или какой этаж у квартир встречается чаще всего
FROM flats_with_advertisements
GROUP BY category_city, category_time 
ORDER BY category_city DESC, category_time;



---------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

-- Напишите ваш запрос здесь
-- определяем аномальные значения
WITH
anomal AS (
    SELECT PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS anomal_total_area,
           PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS anomal_rooms,
           PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS anomal_balcony,
           PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS anomal_max_ceiling_height,
           PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS anomal_min_ceiling_height
    FROM real_estate.flats f 
),
new_flats AS (
    SELECT *
    FROM real_estate.flats  
    WHERE total_area < (SELECT anomal_total_area FROM anomal) 
        AND rooms < (SELECT anomal_rooms FROM anomal) 
        AND balcony < (SELECT anomal_balcony FROM anomal) 
        AND ceiling_height < (SELECT anomal_max_ceiling_height FROM anomal) 
        AND ceiling_height > (SELECT anomal_min_ceiling_height FROM anomal)
),
flats_with_advertisements AS (
    SELECT days_exposition,
    		id,
           TO_CHAR(first_day_exposition, 'Month') AS first_month_exposition,  -- название месяца публикации
           TO_CHAR(first_day_exposition + (days_exposition::int * INTERVAL '1 day'), 'Month') AS last_month_exposition, -- название месяца снятия. (рассчитываем месяц снятия объвления прибавляя к дате публикации кол-во дней активности объявления)
           last_price,
           total_area,
           rooms,
           balcony,
           floor,
           city
    FROM new_flats 
    JOIN real_estate.advertisement a 
    USING(id)
    JOIN real_estate.city c 
    USING(city_id)
    WHERE days_exposition IS NOT NULL -- отсеиваем объявления, которые еще не сняты с продажи
          AND EXTRACT(YEAR FROM first_day_exposition) IN (2015, 2016, 2017, 2018) --учитываем, что нам нужные полные годовые данные по месяцу публикации объвлений, поэтому отсеиваем 2014 и 2019 год, где данные неполные
          AND EXTRACT(YEAR FROM (first_day_exposition + (days_exposition::int * INTERVAL '1 day'))) IN (2015, 2016, 2017, 2018) --учитываем, что нам нужные полные годовые данные по месяцу снятия объвлений, поэтому отсеиваем 2014 и 2019 год, где данные неполные
),
-- рассчитываем активность публикаций в месяц
pub_activity AS (
    SELECT first_month_exposition AS month,
           COUNT(id) AS pub_count, -- количество публикаций
           DENSE_RANK() OVER (ORDER BY COUNT(id) DESC) AS rank_pub,  -- используем DENSE_RANK для учета равных значений, задаем ранг на основе количества публикаций
           ROUND(AVG(last_price::real/total_area)::numeric, 2) AS avg_pub_sqm, -- находим среднюю стоимость квадратного метра
           ROUND(AVG(total_area)::numeric, 2) AS avg_pub_total_area -- находим среднюю площадь недвижимости
    FROM flats_with_advertisements
    GROUP BY first_month_exposition -- группируем по месяцу публикации
),
-- Активность по снятию по месяцам
rem_activity AS (
    SELECT last_month_exposition AS month, 
           COUNT(days_exposition) AS rem_count,
           DENSE_RANK() OVER (ORDER BY COUNT(days_exposition) DESC) AS rank_rem,  -- используем DENSE_RANK для учета равных значений, задаем ранг на основе количества снятий объявлений
           ROUND(AVG(last_price::real / total_area)::numeric, 2) AS avg_rem_sqm, --находим среднюю стоимость квадратного метра
           ROUND(AVG(total_area)::numeric, 2) AS avg_rem_total__area --находим среднюю площадь недвижимости
    FROM flats_with_advertisements
    GROUP BY last_month_exposition --группируем по месяцу снятия публикации
)
-- объединение активности по месяцам для публикации и снятия
SELECT month AS month_name,  -- название месяца
       pub_count, -- количество публикаций
       rank_pub, -- ранг по количеству публикаций
       avg_pub_sqm, -- средняя стоимость кв. метра по месяцу публикации
       avg_pub_total_area, -- средняя площадь недвижимости по месяцу публикации
       rem_count, -- количество снятий объвлений
       rank_rem, -- ранг по количеству снятий объвлений
       avg_rem_sqm, -- средняя стоимость кв. метра по месяцу снятия объвления
       avg_rem_total__area -- средняя площадь недвижимости по месяцу снятия объявлений
FROM pub_activity 
JOIN rem_activity 
USING(month)
ORDER BY rank_pub, rank_rem; -- сортировка по рангу публикаций и рангу снятий объявлений
---------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.
-- Напишите ваш запрос здесь

WITH
anomal AS (
	SELECT PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS anomal_total_area,
		PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS anomal_rooms,
		PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS anomal_balcony,
		PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS anomal_max_ceiling_height,
		PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS anomal_min_ceiling_height
	FROM real_estate.flats f 
),
new_flats AS (
    SELECT *
    FROM real_estate.flats  
    WHERE total_area < (SELECT anomal_total_area FROM anomal) 
        AND rooms < (SELECT anomal_rooms FROM anomal) 
        AND balcony < (SELECT anomal_balcony FROM anomal) 
        AND ceiling_height < (SELECT anomal_max_ceiling_height FROM anomal) 
        AND ceiling_height > (SELECT anomal_min_ceiling_height FROM anomal)
),
city_days_ex AS (
	SELECT city,
	-- разделение по категориям на основе дней активности
			CASE 
				WHEN avg(days_exposition) <= 30 THEN 'месяц'
				WHEN avg(days_exposition) > 30 AND avg(days_exposition) <= 90 THEN 'квартал'
				WHEN avg(days_exposition) > 90 AND avg(days_exposition) <= 180 THEN 'полгода'
				ELSE 'больше полугода'
			END AS category_time, -- разделение на категории по среднему количеству дней активности 
			COUNT(id) AS count_pub, -- количество публикаций 
			ROUND((COUNT(days_exposition)::real/COUNT(id))::NUMERIC, 2) AS share_rem, -- доля снятых публикаций от всех публикаций
			COUNT(days_exposition) AS count_rem, -- количество снятых публикаций
			ROUND(avg(days_exposition)::numeric, 2) AS avg_days_exp, -- среднее количество дней активности 
			ROUND(AVG(last_price::real/total_area)::numeric, 2) AS avg_sqm, -- средняя цена за квадратный метр
			ROUND(AVG(total_area)::numeric)  AS avg_total_area -- средняя площадь квартир
	FROM new_flats
	JOIN real_estate.advertisement a 
	USING(id)
	JOIN real_estate.city c 
	USING(city_id)
	WHERE city != 'Санкт-Петербург' -- исключаем Санкт-Петербург из выборки
	GROUP BY city
)
SELECT *
FROM city_days_ex
WHERE count_pub >= 30 AND avg_days_exp IS NOT NULL --исключаем населенные пункты, где менее 30 объявлений и среднее количество дней активности равно NULL
ORDER BY avg_days_exp; -- сортируем по среднему количеству дней активности




