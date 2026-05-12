-- ============================================================
-- Project: Графовая база данных "Грузоперевозки"
-- Узлы  (NODE): Warehouse (Склады), Truck (Фуры), UnloadingPoint (Точки выгрузки)
-- Рёбра (EDGE): AssignedTo   (Фура → Склад)
--               Route        (Склад → Точка выгрузки)
--               Recommends   (Точка выгрузки → Склад)
--
-- Вариант: Грузоперевозки — склады, фуры, точки выгрузки
--          (грузоподъёмность и маршрут)
-- ============================================================

/*
Created:  12.05.2026
Modified: 12.05.2026
Model:    Microsoft SQL Server 2022
Database: MS SQL Server 2022
*/

-- ============================================================
-- СОЗДАНИЕ И ПОДКЛЮЧЕНИЕ К БАЗЕ ДАННЫХ
-- ============================================================
USE master;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'transport')
BEGIN
    ALTER DATABASE transport SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE transport;
END;
GO

CREATE DATABASE transport
    COLLATE Cyrillic_General_CI_AS;
GO

USE transport;
GO

-- ============================================================
-- ЧАСТЬ 1: СОЗДАНИЕ ТАБЛИЦ УЗЛОВ (NODE TABLES)
-- ============================================================

-- ------------------------------------------------------------
-- Таблица узлов: Warehouse (Склады)
--
-- warehouse_type: distribution | cold_storage | dry_storage
--                 | hazmat | cross_dock
-- Склад является отправной точкой логистической цепи.
-- ------------------------------------------------------------
CREATE TABLE [dbo].[Warehouse]
(
    [warehouse_id]   INT            NOT NULL,
    [name]           NVARCHAR(100)  COLLATE Cyrillic_General_CI_AS NOT NULL,
    [city]           NVARCHAR(50)   COLLATE Cyrillic_General_CI_AS NOT NULL,
    [address]        NVARCHAR(200)  COLLATE Cyrillic_General_CI_AS NOT NULL,
    [warehouse_type] NVARCHAR(20)   COLLATE Cyrillic_General_CI_AS NOT NULL
                     CONSTRAINT CK_Warehouse_type CHECK (
                         [warehouse_type] IN (
                             N'distribution', N'cold_storage',
                             N'dry_storage',  N'hazmat', N'cross_dock'
                         )
                     ),
    [area_sqm]       DECIMAL(9,2)   NOT NULL,
    [capacity_tons]  DECIMAL(9,2)   NOT NULL,
    [is_active]      BIT            NOT NULL DEFAULT (1),
    [open_date]      DATE           NOT NULL
)
AS NODE
ON [PRIMARY];
GO

ALTER TABLE [dbo].[Warehouse]
    ADD CONSTRAINT [PK_Warehouse] PRIMARY KEY ([warehouse_id]);
GO

-- ------------------------------------------------------------
-- Таблица узлов: Truck (Фуры / Грузовики)
--
-- truck_type:  refrigerator | standard | flatbed | tanker | oversized
-- status:      active | maintenance | repair | decommissioned
-- Фура — транспортное средство, приписанное к складу.
-- ------------------------------------------------------------
CREATE TABLE [dbo].[Truck]
(
    [truck_id]        INT            NOT NULL,
    [plate_number]    NVARCHAR(20)   COLLATE Cyrillic_General_CI_AS NOT NULL,
    [brand]           NVARCHAR(50)   COLLATE Cyrillic_General_CI_AS NOT NULL,
    [model]           NVARCHAR(50)   COLLATE Cyrillic_General_CI_AS NOT NULL,
    [year_of_make]    INT            NOT NULL,
    [capacity_tons]   DECIMAL(6,2)   NOT NULL,
    [truck_type]      NVARCHAR(20)   COLLATE Cyrillic_General_CI_AS NOT NULL
                      CONSTRAINT CK_Truck_type CHECK (
                          [truck_type] IN (
                              N'refrigerator', N'standard',
                              N'flatbed',       N'tanker', N'oversized'
                          )
                      ),
    [status]          NVARCHAR(20)   COLLATE Cyrillic_General_CI_AS NOT NULL DEFAULT (N'active')
                      CONSTRAINT CK_Truck_status CHECK (
                          [status] IN (
                              N'active', N'maintenance',
                              N'repair', N'decommissioned'
                          )
                      ),
    [fuel_type]       NVARCHAR(20)   COLLATE Cyrillic_General_CI_AS NOT NULL
                      CONSTRAINT CK_Truck_fuel CHECK (
                          [fuel_type] IN (N'diesel', N'gas', N'electric', N'hybrid')
                      ),
    [mileage_km]      INT            NOT NULL DEFAULT (0),
    [reg_date]        DATE           NOT NULL
)
AS NODE
ON [PRIMARY];
GO

ALTER TABLE [dbo].[Truck]
    ADD CONSTRAINT [PK_Truck] PRIMARY KEY ([truck_id]);
GO

-- ------------------------------------------------------------
-- Таблица узлов: UnloadingPoint (Точки выгрузки)
--
-- point_type: retail | warehouse | construction | cold_chain | port
-- Точка выгрузки — конечный получатель груза.
-- ------------------------------------------------------------
CREATE TABLE [dbo].[UnloadingPoint]
(
    [point_id]      INT            NOT NULL,
    [name]          NVARCHAR(100)  COLLATE Cyrillic_General_CI_AS NOT NULL,
    [city]          NVARCHAR(50)   COLLATE Cyrillic_General_CI_AS NOT NULL,
    [address]       NVARCHAR(200)  COLLATE Cyrillic_General_CI_AS NOT NULL,
    [point_type]    NVARCHAR(20)   COLLATE Cyrillic_General_CI_AS NOT NULL
                    CONSTRAINT CK_Point_type CHECK (
                        [point_type] IN (
                            N'retail', N'warehouse',
                            N'construction', N'cold_chain', N'port'
                        )
                    ),
    [working_hours] NVARCHAR(30)   COLLATE Cyrillic_General_CI_AS NOT NULL,
    [has_forklift]  BIT            NOT NULL DEFAULT (0),
    [max_truck_tons] DECIMAL(6,2)  NOT NULL,
    [contact_phone] NVARCHAR(20)   COLLATE Cyrillic_General_CI_AS NOT NULL
)
AS NODE
ON [PRIMARY];
GO

ALTER TABLE [dbo].[UnloadingPoint]
    ADD CONSTRAINT [PK_UnloadingPoint] PRIMARY KEY ([point_id]);
GO


-- ============================================================
-- ЧАСТЬ 2: СОЗДАНИЕ ТАБЛИЦ РЁБЕР (EDGE TABLES)
-- ============================================================

-- ------------------------------------------------------------
-- Ребро: AssignedTo (Truck → Warehouse)
-- Фура приписана к складу (место базирования).
-- Направление: Фура → Склад (односторонняя связь).
-- assignment_type: permanent | temporary | seasonal
-- ------------------------------------------------------------
CREATE TABLE [dbo].[AssignedTo]
(
    [assigned_date]   DATE           NOT NULL,
    [assignment_type] NVARCHAR(15)   COLLATE Cyrillic_General_CI_AS NOT NULL DEFAULT (N'permanent')
                      CONSTRAINT CK_Assignment_type CHECK (
                          [assignment_type] IN (N'permanent', N'temporary', N'seasonal')
                      ),
    [is_active]       BIT            NOT NULL DEFAULT (1),
    [notes]           NVARCHAR(300)  COLLATE Cyrillic_General_CI_AS NULL
)
AS EDGE
ON [PRIMARY];
GO

ALTER TABLE [dbo].[AssignedTo]
    ADD CONSTRAINT [EC_AssignedTo] CONNECTION (
        [Truck] TO [Warehouse]
    );
GO

-- ------------------------------------------------------------
-- Ребро: Route (Warehouse → UnloadingPoint)
-- Маршрут со склада до точки выгрузки.
-- Направление: Склад → Точка выгрузки (односторонняя).
-- route_status: active | suspended | seasonal | planned
-- ------------------------------------------------------------
CREATE TABLE [dbo].[Route]
(
    [distance_km]   INT            NOT NULL,
    [avg_time_hrs]  DECIMAL(5,2)   NOT NULL,
    [route_status]  NVARCHAR(15)   COLLATE Cyrillic_General_CI_AS NOT NULL DEFAULT (N'active')
                    CONSTRAINT CK_Route_status CHECK (
                        [route_status] IN (N'active', N'suspended', N'seasonal', N'planned')
                    ),
    [toll_cost_rub] DECIMAL(8,2)   NOT NULL DEFAULT (0),
    [priority]      TINYINT        NOT NULL DEFAULT (3)
                    CONSTRAINT CK_Route_priority CHECK ([priority] BETWEEN 1 AND 5),
    [opened_date]   DATE           NOT NULL
)
AS EDGE
ON [PRIMARY];
GO

ALTER TABLE [dbo].[Route]
    ADD CONSTRAINT [EC_Route] CONNECTION (
        [Warehouse] TO [UnloadingPoint]
    );
GO

-- ------------------------------------------------------------
-- Ребро: Recommends (UnloadingPoint → Warehouse)
-- Точка выгрузки рекомендует склад для будущих поставок
-- (обратная связь логистической цепи).
-- Направление: Точка → Склад (односторонняя).
-- rec_status: approved | pending | rejected
-- ------------------------------------------------------------
CREATE TABLE [dbo].[Recommends]
(
    [rec_date]     DATE           NOT NULL,
    [rec_status]   NVARCHAR(15)   COLLATE Cyrillic_General_CI_AS NOT NULL DEFAULT (N'approved')
                   CONSTRAINT CK_Rec_status CHECK (
                       [rec_status] IN (N'approved', N'pending', N'rejected')
                   ),
    [rating]       TINYINT        NOT NULL
                   CONSTRAINT CK_Rec_rating CHECK ([rating] BETWEEN 1 AND 5),
    [comment]      NVARCHAR(300)  COLLATE Cyrillic_General_CI_AS NULL
)
AS EDGE
ON [PRIMARY];
GO

ALTER TABLE [dbo].[Recommends]
    ADD CONSTRAINT [EC_Recommends] CONNECTION (
        [UnloadingPoint] TO [Warehouse]
    );
GO

-- ------------------------------------------------------------
-- Ребро: Delivers (Truck → UnloadingPoint)
-- Фура осуществила доставку груза в точку выгрузки.
-- Направление: Фура → Точка выгрузки (односторонняя).
-- Хранит историю каждой конкретной доставки.
-- ------------------------------------------------------------
CREATE TABLE [dbo].[Delivers]
(
    [delivery_date]  DATE           NOT NULL,
    [cargo_tons]     DECIMAL(6,2)   NOT NULL,
    [cargo_type]     NVARCHAR(50)   COLLATE Cyrillic_General_CI_AS NOT NULL,
    [delivery_status] NVARCHAR(15)  COLLATE Cyrillic_General_CI_AS NOT NULL DEFAULT (N'completed')
                      CONSTRAINT CK_Delivery_status CHECK (
                          [delivery_status] IN (
                              N'completed', N'partial', N'failed', N'returned'
                          )
                      ),
    [distance_km]    INT            NOT NULL,
    [duration_hrs]   DECIMAL(5,2)   NOT NULL
)
AS EDGE
ON [PRIMARY];
GO

ALTER TABLE [dbo].[Delivers]
    ADD CONSTRAINT [EC_Delivers] CONNECTION (
        [Truck] TO [UnloadingPoint]
    );
GO


-- ============================================================
-- ЧАСТЬ 3: ЗАПОЛНЕНИЕ ТАБЛИЦ УЗЛОВ
-- ============================================================

-- ------------------------------------------------------------
-- 3.1 Данные: Warehouse (10 складов)
-- ------------------------------------------------------------
INSERT INTO [dbo].[Warehouse]
    (warehouse_id, name, city, address, warehouse_type,
     area_sqm, capacity_tons, is_active, open_date)
VALUES
    (1,  N'Центральный распределительный склад',
         N'Москва',
         N'Москва, Складской пер., 12',
         N'distribution',  18500.00, 5000.00, 1, '2010-03-15'),
    (2,  N'Северный холодильный склад',
         N'Санкт-Петербург',
         N'Санкт-Петербург, ул. Промышленная, 7',
         N'cold_storage',   9200.00, 2400.00, 1, '2013-06-01'),
    (3,  N'Южный сухой склад',
         N'Ростов-на-Дону',
         N'Ростов-на-Дону, пр. Логистический, 3',
         N'dry_storage',   12000.00, 3200.00, 1, '2015-09-20'),
    (4,  N'Уральский кросс-докинг центр',
         N'Екатеринбург',
         N'Екатеринбург, ул. Транспортная, 45',
         N'cross_dock',     6500.00, 1800.00, 1, '2017-02-10'),
    (5,  N'Западный таможенный склад',
         N'Калининград',
         N'Калининград, ул. Портовая, 1',
         N'distribution',   8000.00, 2000.00, 1, '2014-11-05'),
    (6,  N'Сибирский склад опасных грузов',
         N'Новосибирск',
         N'Новосибирск, Промзона Северная, 8',
         N'hazmat',         4200.00,  900.00, 1, '2018-04-22'),
    (7,  N'Приволжский распределительный склад',
         N'Казань',
         N'Казань, ул. Индустриальная, 19',
         N'distribution',  10500.00, 2800.00, 1, '2016-07-14'),
    (8,  N'Уральский сухой склад',
         N'Челябинск',
         N'Челябинск, ул. Складская, 33',
         N'dry_storage',    7800.00, 2100.00, 1, '2019-01-30'),
    (9,  N'Дальневосточный портовый склад',
         N'Владивосток',
         N'Владивосток, Портовый тупик, 2',
         N'distribution',  15000.00, 4200.00, 1, '2012-08-08'),
    (10, N'Кавказский холодильный склад',
         N'Ставрополь',
         N'Ставрополь, ул. Прохладная, 6',
         N'cold_storage',   5600.00, 1500.00, 1, '2020-05-17');
GO

-- ------------------------------------------------------------
-- 3.2 Данные: Truck (12 фур)
-- ------------------------------------------------------------
INSERT INTO [dbo].[Truck]
    (truck_id, plate_number, brand, model, year_of_make,
     capacity_tons, truck_type, status, fuel_type, mileage_km, reg_date)
VALUES
    (1,  N'А123ВС77',  N'КАМАЗ',  N'5490-S5',        2019, 20.00, N'standard',     N'active',       N'diesel',  185000, '2019-04-01'),
    (2,  N'В456КМ78',  N'МАЗ',    N'6430A9',          2018, 15.00, N'standard',     N'active',       N'diesel',  210000, '2018-07-15'),
    (3,  N'Е789НО161', N'Volvo',   N'FH500',           2021, 25.00, N'refrigerator', N'active',       N'diesel',   92000, '2021-02-20'),
    (4,  N'К012РТ96',  N'КАМАЗ',  N'6522-25',         2017, 18.00, N'flatbed',      N'maintenance',  N'diesel',  325000, '2017-11-10'),
    (5,  N'М345УХ54',  N'Scania',  N'R500',            2022, 22.00, N'standard',     N'active',       N'diesel',   47000, '2022-06-05'),
    (6,  N'Н678ЦФ39',  N'DAF',     N'XF480',           2020, 10.00, N'refrigerator', N'active',       N'diesel',  138000, '2020-09-12'),
    (7,  N'О901ЧШ23',  N'МАЗ',    N'6501A5',          2016, 30.00, N'flatbed',      N'active',       N'diesel',  410000, '2016-03-28'),
    (8,  N'Р234ЩЭ59',  N'Mercedes',N'Actros 1851',    2020, 16.00, N'standard',     N'repair',       N'diesel',  267000, '2020-01-18'),
    (9,  N'С567ЮЯ77',  N'Volvo',   N'FH750',           2023, 28.00, N'oversized',    N'active',       N'diesel',    8000, '2023-08-30'),
    (10, N'Т890АБ98',  N'КАМАЗ',  N'5350',            2015, 12.00, N'tanker',       N'active',       N'gas',    520000, '2015-06-14'),
    (11, N'У111ВГ197', N'Scania',  N'G360',            2021, 19.00, N'standard',     N'active',       N'hybrid',   65000, '2021-10-03'),
    (12, N'Х222ДЕ199', N'Volvo',   N'FE250 Electric',  2024,  8.00, N'refrigerator', N'active',       N'electric',  3500, '2024-01-22');
GO

-- ------------------------------------------------------------
-- 3.3 Данные: UnloadingPoint (10 точек выгрузки)
-- ------------------------------------------------------------
INSERT INTO [dbo].[UnloadingPoint]
    (point_id, name, city, address, point_type,
     working_hours, has_forklift, max_truck_tons, contact_phone)
VALUES
    (1,  N'ТЦ Мега',
         N'Москва',
         N'Москва, ул. Ленина, 1',
         N'retail',        N'07:00-23:00', 1, 20.00, N'+7-495-111-0001'),
    (2,  N'Гипермаркет Лента',
         N'Санкт-Петербург',
         N'Санкт-Петербург, пр. Мира, 15',
         N'retail',        N'08:00-22:00', 1, 25.00, N'+7-812-222-0002'),
    (3,  N'Строительный рынок Атлант',
         N'Ростов-на-Дону',
         N'Ростов-на-Дону, ул. Пушкина, 20',
         N'construction',  N'06:00-20:00', 0, 30.00, N'+7-863-333-0003'),
    (4,  N'ТЦ Гринвич',
         N'Екатеринбург',
         N'Екатеринбург, ул. Ленина, 5',
         N'retail',        N'10:00-22:00', 1, 15.00, N'+7-343-444-0004'),
    (5,  N'Холодильный терминал Балтика',
         N'Калининград',
         N'Калининград, ул. Гагарина, 7',
         N'cold_chain',    N'00:00-24:00', 1, 25.00, N'+7-401-555-0005'),
    (6,  N'ТРЦ Аура',
         N'Новосибирск',
         N'Новосибирск, ул. Кирова, 10',
         N'retail',        N'09:00-22:00', 1, 20.00, N'+7-383-666-0006'),
    (7,  N'Стройбаза Мегастрой',
         N'Казань',
         N'Казань, ул. Декабристов, 3',
         N'construction',  N'07:00-19:00', 1, 30.00, N'+7-843-777-0007'),
    (8,  N'Стройпарк Уральский',
         N'Челябинск',
         N'Челябинск, ул. Лесная, 12',
         N'construction',  N'07:00-20:00', 0, 28.00, N'+7-351-888-0008'),
    (9,  N'Портовый грузовой терминал',
         N'Владивосток',
         N'Владивосток, ул. Морская, 25',
         N'port',          N'00:00-24:00', 1, 30.00, N'+7-423-999-0009'),
    (10, N'Гастрономъ — оптовая база',
         N'Ставрополь',
         N'Ставрополь, ул. Мира, 8',
         N'retail',        N'08:00-20:00', 0, 12.00, N'+7-865-100-0010');
GO


-- ============================================================
-- ЧАСТЬ 4: ЗАПОЛНЕНИЕ ТАБЛИЦ РЁБЕР
-- ============================================================

-- ------------------------------------------------------------
-- 4.1 AssignedTo: Фура → Склад
-- Каждая фура приписана к одному базовому складу.
--
-- Схема распределения:
-- Склад 1 (Москва):      Фуры  1, 5,  9
-- Склад 2 (СПб):         Фуры  2,  6
-- Склад 3 (Ростов):      Фуры  3, 11
-- Склад 4 (Екатеринбург):Фуры  4
-- Склад 5 (Калининград): Фуры 12
-- Склад 6 (Новосибирск): Фуры  7
-- Склад 7 (Казань):      Фуры  8
-- Склад 9 (Владивосток): Фуры 10
-- ------------------------------------------------------------
INSERT INTO [dbo].[AssignedTo]
    ($from_id, $to_id, assigned_date, assignment_type, is_active, notes)
VALUES
    -- Москва — флагманский склад, три фуры
    ((SELECT $node_id FROM Truck WHERE truck_id = 1),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 1),
     '2019-04-01', N'permanent', 1,
     N'Основная фура Центрального склада, маршруты по МСК и МО'),

    ((SELECT $node_id FROM Truck WHERE truck_id = 5),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 1),
     '2022-06-05', N'permanent', 1,
     N'Новая фура Scania, дальние рейсы'),

    ((SELECT $node_id FROM Truck WHERE truck_id = 9),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 1),
     '2023-08-30', N'permanent', 1,
     N'Негабаритный транспорт для крупных партий'),

    -- Санкт-Петербург
    ((SELECT $node_id FROM Truck WHERE truck_id = 2),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 2),
     '2018-07-15', N'permanent', 1,
     N'МАЗ для городских развозок СПб'),

    ((SELECT $node_id FROM Truck WHERE truck_id = 6),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 2),
     '2020-09-12', N'permanent', 1,
     N'Рефрижератор для холодильного склада'),

    -- Ростов-на-Дону
    ((SELECT $node_id FROM Truck WHERE truck_id = 3),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 3),
     '2021-02-20', N'permanent', 1,
     N'Рефрижератор, южное направление'),

    ((SELECT $node_id FROM Truck WHERE truck_id = 11),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 3),
     '2021-10-03', N'permanent', 1,
     N'Гибридная фура, экологичный маршрут'),

    -- Екатеринбург — на техобслуживании
    ((SELECT $node_id FROM Truck WHERE truck_id = 4),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 4),
     '2017-11-10', N'permanent', 0,
     N'Фура на техническом обслуживании'),

    -- Калининград — электрическая фура
    ((SELECT $node_id FROM Truck WHERE truck_id = 12),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 5),
     '2024-01-22', N'permanent', 1,
     N'Электрорефрижератор, короткие городские маршруты'),

    -- Новосибирск
    ((SELECT $node_id FROM Truck WHERE truck_id = 7),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 6),
     '2016-03-28', N'permanent', 1,
     N'Длинномер для стройматериалов'),

    -- Казань — в ремонте
    ((SELECT $node_id FROM Truck WHERE truck_id = 8),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 7),
     '2020-01-18', N'permanent', 0,
     N'Фура на ремонте после ДТП'),

    -- Владивосток
    ((SELECT $node_id FROM Truck WHERE truck_id = 10),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 9),
     '2015-06-14', N'permanent', 1,
     N'Автоцистерна, доставка жидких грузов в порт');
GO

-- ------------------------------------------------------------
-- 4.2 Route: Склад → Точка выгрузки
-- Логистические маршруты между складами и получателями.
--
-- Каждый склад обслуживает 1-3 точки выгрузки.
-- ------------------------------------------------------------
INSERT INTO [dbo].[Route]
    ($from_id, $to_id, distance_km, avg_time_hrs,
     route_status, toll_cost_rub, priority, opened_date)
VALUES
    -- Склад 1 (Москва) → ТЦ Мега (Москва) — городской, приоритет 1
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 1),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 1),
     12, 0.50, N'active', 0.00, 1, '2010-05-01'),

    -- Склад 1 (Москва) → ТЦ Гринвич (Екатеринбург) — дальний
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 1),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 4),
     1780, 22.00, N'active', 4200.00, 3, '2012-01-15'),

    -- Склад 2 (СПб) → Гипермаркет Лента (СПб) — городской
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 2),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 2),
     18, 0.75, N'active', 0.00, 1, '2013-07-01'),

    -- Склад 2 (СПб) → Холодильный терминал Балтика (Калининград)
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 2),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 5),
     800, 12.00, N'active', 1800.00, 2, '2015-03-10'),

    -- Склад 3 (Ростов) → Строительный рынок Атлант (Ростов)
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 3),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 3),
     25, 0.60, N'active', 0.00, 1, '2015-10-01'),

    -- Склад 3 (Ростов) → Гастрономъ (Ставрополь)
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 3),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 10),
     220, 3.50, N'active', 320.00, 2, '2016-04-20'),

    -- Склад 4 (Екатеринбург) → ТЦ Гринвич (Екатеринбург)
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 4),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 4),
     8, 0.30, N'active', 0.00, 1, '2017-03-01'),

    -- Склад 4 (Екатеринбург) → Стройпарк Уральский (Челябинск)
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 4),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 8),
     210, 3.00, N'active', 280.00, 2, '2017-06-15'),

    -- Склад 5 (Калининград) → Холодильный терминал Балтика (Калининград)
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 5),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 5),
     15, 0.40, N'active', 0.00, 1, '2014-12-01'),

    -- Склад 6 (Новосибирск) → ТРЦ Аура (Новосибирск)
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 6),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 6),
     22, 0.55, N'active', 0.00, 1, '2018-05-01'),

    -- Склад 7 (Казань) → Стройбаза Мегастрой (Казань)
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 7),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 7),
     30, 0.80, N'active', 0.00, 1, '2016-08-01'),

    -- Склад 8 (Челябинск) → Стройпарк Уральский (Челябинск)
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 8),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 8),
     18, 0.50, N'active', 0.00, 1, '2019-02-15'),

    -- Склад 9 (Владивосток) → Портовый грузовой терминал (Владивосток)
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 9),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 9),
     10, 0.35, N'active', 0.00, 1, '2012-09-01'),

    -- Склад 10 (Ставрополь) → Гастрономъ (Ставрополь)
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 10),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 10),
     12, 0.40, N'active', 0.00, 1, '2020-06-01'),

    -- Склад 10 (Ставрополь) → Строительный рынок Атлант (Ростов) — сезонный
    ((SELECT $node_id FROM Warehouse WHERE warehouse_id = 10),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 3),
     340, 5.00, N'seasonal', 480.00, 4, '2021-03-01');
GO

-- ------------------------------------------------------------
-- 4.3 Recommends: Точка выгрузки → Склад
-- Точка рекомендует склад для будущих поставок (обратная связь).
-- ------------------------------------------------------------
INSERT INTO [dbo].[Recommends]
    ($from_id, $to_id, rec_date, rec_status, rating, comment)
VALUES
    -- ТЦ Мега рекомендует Центральный склад (свой основной поставщик)
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 1),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 1),
     '2023-02-10', N'approved', 5,
     N'Отличная своевременность поставок, рекомендуем к продолжению контракта'),

    -- Гипермаркет Лента рекомендует Северный склад
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 2),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 2),
     '2023-03-15', N'approved', 4,
     N'Хорошее качество холодовой цепи, незначительные задержки'),

    -- Строительный рынок рекомендует Южный склад
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 3),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 3),
     '2023-04-20', N'approved', 4,
     N'Надёжный поставщик стройматериалов'),

    -- ТЦ Гринвич рекомендует Уральский кросс-докинг
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 4),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 4),
     '2023-05-05', N'approved', 5,
     N'Быстрая перевалка, минимальное время ожидания'),

    -- Холодильный терминал Балтика рекомендует Западный склад
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 5),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 5),
     '2023-06-12', N'approved', 3,
     N'Удобное расположение, но бывают перебои с температурным режимом'),

    -- ТРЦ Аура рекомендует Сибирский склад
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 6),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 6),
     '2023-07-18', N'approved', 5,
     N'Лучший склад в регионе, всегда точно в срок'),

    -- Стройбаза Мегастрой рекомендует Приволжский склад
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 7),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 7),
     '2023-08-22', N'approved', 4,
     N'Хорошая комплектация заказов, рекомендуем'),

    -- Стройпарк рекомендует Уральский сухой склад
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 8),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 8),
     '2023-09-30', N'pending', 3,
     N'На рассмотрении, были случаи пересортицы'),

    -- Портовый терминал рекомендует Дальневосточный склад
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 9),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 9),
     '2023-10-15', N'approved', 5,
     N'Единственный полноценный склад под нужды порта, незаменим'),

    -- Гастрономъ рекомендует Кавказский холодильный склад
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 10),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 10),
     '2023-11-05', N'approved', 4,
     N'Свежая продукция, соблюдается холодовая цепь'),

    -- Холодильный терминал также рекомендует Северный склад (как альтернативу)
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 5),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 2),
     '2024-01-20', N'approved', 4,
     N'Альтернативный поставщик по холодовой цепи из СПб'),

    -- ТЦ Мега дополнительно рекомендует Приволжский склад (тест нового поставщика)
    ((SELECT $node_id FROM UnloadingPoint WHERE point_id = 1),
     (SELECT $node_id FROM Warehouse WHERE warehouse_id = 7),
     '2024-02-28', N'pending', 3,
     N'Тестовая поставка, оцениваем нового поставщика');
GO

-- ------------------------------------------------------------
-- 4.4 Delivers: Фура → Точка выгрузки
-- История доставок.
-- ------------------------------------------------------------
INSERT INTO [dbo].[Delivers]
    ($from_id, $to_id, delivery_date, cargo_tons, cargo_type,
     delivery_status, distance_km, duration_hrs)
VALUES
    -- Фура 1 (А123ВС77) → ТЦ Мега
    ((SELECT $node_id FROM Truck WHERE truck_id = 1),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 1),
     '2024-01-15', 18.50, N'Бытовая техника',
     N'completed', 12, 0.60),

    -- Фура 1 → ТЦ Гринвич (дальний рейс)
    ((SELECT $node_id FROM Truck WHERE truck_id = 1),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 4),
     '2024-02-03', 19.20, N'Промышленное оборудование',
     N'completed', 1780, 23.50),

    -- Фура 3 (Е789НО161, рефрижератор) → Гипермаркет Лента
    ((SELECT $node_id FROM Truck WHERE truck_id = 3),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 2),
     '2024-01-20', 22.00, N'Замороженные продукты',
     N'completed', 18, 0.90),

    -- Фура 3 → Холодильный терминал Балтика
    ((SELECT $node_id FROM Truck WHERE truck_id = 3),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 5),
     '2024-02-14', 24.00, N'Мороженая рыба',
     N'completed', 800, 13.20),

    -- Фура 5 (М345УХ54, Scania) → ТЦ Мега
    ((SELECT $node_id FROM Truck WHERE truck_id = 5),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 1),
     '2024-01-28', 21.00, N'Мебель',
     N'completed', 12, 0.55),

    -- Фура 7 (О901ЧШ23, длинномер) → Строительный рынок Атлант
    ((SELECT $node_id FROM Truck WHERE truck_id = 7),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 3),
     '2024-01-10', 28.00, N'Металлоконструкции',
     N'completed', 25, 0.80),

    -- Фура 7 → Стройбаза Мегастрой
    ((SELECT $node_id FROM Truck WHERE truck_id = 7),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 7),
     '2024-02-25', 27.50, N'Кирпич и блоки',
     N'completed', 30, 1.00),

    -- Фура 9 (С567ЮЯ77, негабарит) → Портовый терминал
    ((SELECT $node_id FROM Truck WHERE truck_id = 9),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 9),
     '2024-03-01', 26.00, N'Промышленное оборудование',
     N'completed', 10, 0.50),

    -- Фура 10 (Т890АБ98, цистерна) → Портовый терминал
    ((SELECT $node_id FROM Truck WHERE truck_id = 10),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 9),
     '2024-02-18', 11.00, N'Техническое масло',
     N'completed', 10, 0.45),

    -- Фура 6 (Н678ЦФ39, рефрижератор) → Гастрономъ
    ((SELECT $node_id FROM Truck WHERE truck_id = 6),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 10),
     '2024-01-30', 9.50, N'Свежие продукты',
     N'partial', 220, 4.20),

    -- Фура 11 (У111ВГ197, гибрид) → ТРЦ Аура
    ((SELECT $node_id FROM Truck WHERE truck_id = 11),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 6),
     '2024-03-05', 17.00, N'Одежда и обувь',
     N'completed', 22, 0.70),

    -- Фура 12 (электро) → Холодильный терминал Балтика (короткий рейс)
    ((SELECT $node_id FROM Truck WHERE truck_id = 12),
     (SELECT $node_id FROM UnloadingPoint WHERE point_id = 5),
     '2024-03-10',  7.00, N'Молочная продукция',
     N'completed', 15, 0.50);
GO


-- ============================================================
-- ПРОВЕРОЧНЫЙ ЗАПРОС: количество строк в каждой таблице
-- ============================================================
SELECT N'Warehouse'      AS [Таблица], COUNT(*) AS [Строк] FROM Warehouse
UNION ALL
SELECT N'Truck',                        COUNT(*)           FROM Truck
UNION ALL
SELECT N'UnloadingPoint',               COUNT(*)           FROM UnloadingPoint
UNION ALL
SELECT N'AssignedTo (EDGE)',            COUNT(*)           FROM AssignedTo
UNION ALL
SELECT N'Route (EDGE)',                 COUNT(*)           FROM Route
UNION ALL
SELECT N'Recommends (EDGE)',            COUNT(*)           FROM Recommends
UNION ALL
SELECT N'Delivers (EDGE)',              COUNT(*)           FROM Delivers;
GO


-- ============================================================
-- ЧАСТЬ 5: ЗАПРОСЫ С MATCH (не менее 5, цепочки 3+ узлов)
-- ============================================================

-- ------------------------------------------------------------
-- Запрос 1: Все фуры, их склады и точки выгрузки,
--           к которым ведут маршруты со склада.
-- Цепочка: Truck → (AssignedTo) → Warehouse → (Route) → UnloadingPoint
-- ------------------------------------------------------------
PRINT N'=== Запрос 1: Фуры — склады — точки выгрузки ===';
SELECT
    tr.plate_number                    AS [Фура],
    tr.brand + N' ' + tr.model        AS [Марка/модель],
    tr.capacity_tons                   AS [Грузоподъёмность (т)],
    w.name                             AS [Склад],
    w.city                             AS [Город склада],
    up.name                            AS [Точка выгрузки],
    r.distance_km                      AS [Дистанция (км)],
    r.avg_time_hrs                     AS [Время в пути (ч)],
    r.route_status                     AS [Статус маршрута]
FROM Truck          AS tr
   , AssignedTo     AS at
   , Warehouse      AS w
   , Route          AS r
   , UnloadingPoint AS up
WHERE MATCH(tr-(at)->w-(r)->up)
ORDER BY w.city, tr.plate_number;
GO

-- ------------------------------------------------------------
-- Запрос 2: Фуры с грузоподъёмностью >= 20 т,
--           обслуживающие склады с дальними маршрутами (> 500 км).
-- Цепочка: Truck → (AssignedTo) → Warehouse → (Route) → UnloadingPoint
-- ------------------------------------------------------------
PRINT N'=== Запрос 2: Мощные фуры на дальних маршрутах (>500 км) ===';
SELECT
    tr.plate_number                    AS [Номер фуры],
    tr.brand + N' ' + tr.model        AS [Марка],
    tr.capacity_tons                   AS [Грузоподъёмность (т)],
    tr.fuel_type                       AS [Тип топлива],
    w.name                             AS [Склад],
    r.distance_km                      AS [Расстояние (км)],
    r.toll_cost_rub                    AS [Стоимость проезда (руб)],
    up.name                            AS [Точка выгрузки],
    up.city                            AS [Город назначения]
FROM Truck          AS tr
   , AssignedTo     AS at
   , Warehouse      AS w
   , Route          AS r
   , UnloadingPoint AS up
WHERE MATCH(tr-(at)->w-(r)->up)
  AND tr.capacity_tons >= 20
  AND r.distance_km    >  500
ORDER BY r.distance_km DESC;
GO

-- ------------------------------------------------------------
-- Запрос 3: Склады, рекомендованные точками выгрузки,
--           с фурами, которые к ним приписаны.
-- Цепочка: UnloadingPoint → (Recommends) → Warehouse → (AssignedTo) → Truck
-- ------------------------------------------------------------
PRINT N'=== Запрос 3: Рекомендованные склады и их флот ===';
SELECT
    up.name                            AS [Точка выгрузки],
    up.city                            AS [Город точки],
    rec.rating                         AS [Рейтинг],
    rec.rec_status                     AS [Статус рекомендации],
    w.name                             AS [Рекомендованный склад],
    w.city                             AS [Город склада],
    tr.plate_number                    AS [Фура],
    tr.truck_type                      AS [Тип фуры],
    tr.capacity_tons                   AS [Грузоподъёмность (т)],
    tr.status                          AS [Статус фуры]
FROM UnloadingPoint AS up
   , Recommends     AS rec
   , Warehouse      AS w
   , AssignedTo     AS at
   , Truck          AS tr
WHERE MATCH(up-(rec)->w-(at)->tr)
  AND rec.rec_status = N'approved'
ORDER BY rec.rating DESC, w.name;
GO

-- ------------------------------------------------------------
-- Запрос 4: Фуры, выполнившие доставки, при условии что
--           их склад получил оценку >= 4 от точки назначения.
-- Цепочка: Truck → (Delivers) → UnloadingPoint → (Recommends) → Warehouse
-- ------------------------------------------------------------
PRINT N'=== Запрос 4: Доставки фур на точки с высоким рейтингом склада ===';
SELECT
    tr.plate_number                    AS [Фура],
    tr.brand + N' ' + tr.model        AS [Марка],
    d.delivery_date                    AS [Дата доставки],
    d.cargo_tons                       AS [Груз (т)],
    d.cargo_type                       AS [Тип груза],
    d.delivery_status                  AS [Статус доставки],
    up.name                            AS [Точка выгрузки],
    up.city                            AS [Город],
    rec.rating                         AS [Рейтинг склада от точки],
    w.name                             AS [Рекомендованный склад]
FROM Truck          AS tr
   , Delivers       AS d
   , UnloadingPoint AS up
   , Recommends     AS rec
   , Warehouse      AS w
WHERE MATCH(tr-(d)->up-(rec)->w)
  AND rec.rating     >= 4
  AND d.delivery_status = N'completed'
ORDER BY d.delivery_date DESC;
GO

-- ------------------------------------------------------------
-- Запрос 5: Рефрижераторные фуры и их маршруты к холодовым
--           точкам (cold_chain и retail с холодовой цепью).
-- Цепочка: Truck → (AssignedTo) → Warehouse → (Route) → UnloadingPoint
-- ------------------------------------------------------------
PRINT N'=== Запрос 5: Рефрижераторы и холодовые цепи поставок ===';
SELECT
    tr.plate_number                    AS [Фура-рефрижератор],
    tr.capacity_tons                   AS [Грузоподъёмность (т)],
    tr.year_of_make                    AS [Год выпуска],
    w.name                             AS [Базовый склад],
    w.warehouse_type                   AS [Тип склада],
    up.name                            AS [Точка выгрузки],
    up.point_type                      AS [Тип точки],
    r.distance_km                      AS [Расстояние (км)],
    r.avg_time_hrs                     AS [Время (ч)]
FROM Truck          AS tr
   , AssignedTo     AS at
   , Warehouse      AS w
   , Route          AS r
   , UnloadingPoint AS up
WHERE MATCH(tr-(at)->w-(r)->up)
  AND tr.truck_type     = N'refrigerator'
  AND up.point_type IN (N'cold_chain', N'retail')
ORDER BY tr.plate_number;
GO

-- ------------------------------------------------------------
-- Запрос 6 (бонус): Полная цепочка — фура → склад → точка →
--           рекомендуемый склад. Анализ логистического цикла.
-- Цепочка: Truck → (AssignedTo) → Warehouse → (Route) → UnloadingPoint
--          → (Recommends) → Warehouse2
-- ------------------------------------------------------------
PRINT N'=== Запрос 6 (бонус): Полный логистический цикл Фура→Склад→Точка→СкладРекомендация ===';
SELECT
    tr.plate_number                    AS [Фура],
    w1.name                            AS [Склад отправки],
    w1.city                            AS [Город отправки],
    r.distance_km                      AS [Дистанция (км)],
    up.name                            AS [Точка выгрузки],
    rec.rating                         AS [Рейтинг],
    w2.name                            AS [Рекомендованный склад],
    w2.city                            AS [Город склада]
FROM Truck          AS tr
   , AssignedTo     AS at
   , Warehouse      AS w1
   , Route          AS r
   , UnloadingPoint AS up
   , Recommends     AS rec
   , Warehouse      AS w2
WHERE MATCH(tr-(at)->w1-(r)->up-(rec)->w2)
ORDER BY r.distance_km DESC;
GO


-- ============================================================
-- ЧАСТЬ 6: ЗАПРОСЫ SHORTEST_PATH
-- ============================================================

-- ------------------------------------------------------------
-- SP-Запрос 1: Шаблон "+"
-- Найти все цепочки от склада через маршруты до точек выгрузки
-- (1 и более шагов).
-- Путь: Warehouse → (Route) → UnloadingPoint → (Recommends) →
--       Warehouse → ...
-- Используем цикл: склад → точка → склад →точка...
--
-- Поскольку Route идёт Warehouse→UnloadingPoint, а Recommends
-- идёт UnloadingPoint→Warehouse, можно чередовать через
-- единый тип узла Warehouse как «опорный».
-- Строим путь: Warehouse -(Route)-> UnloadingPoint -(Recommends)->
--              Warehouse повторяем 1+ раз.
-- ------------------------------------------------------------
PRINT N'=== SP-Запрос 1: Цепочки склад→точка→склад (шаблон +) ===';
SELECT
    w_start.name                                                        AS [Начальный склад],
    STRING_AGG(up.name, N' -> ') WITHIN GROUP (GRAPH PATH)             AS [Посещённые точки выгрузки],
    STRING_AGG(w_end.name, N' -> ') WITHIN GROUP (GRAPH PATH)          AS [Возврат к складам],
    COUNT(up.name)               WITHIN GROUP (GRAPH PATH)             AS [Количество шагов],
    LAST_VALUE(w_end.name)       WITHIN GROUP (GRAPH PATH)             AS [Конечный склад]
FROM Warehouse      AS w_start
   , Route          FOR PATH AS r
   , UnloadingPoint FOR PATH AS up
   , Recommends     FOR PATH AS rec
   , Warehouse      FOR PATH AS w_end
WHERE MATCH(SHORTEST_PATH(w_start(-(r)->up-(rec)->w_end)+))
ORDER BY w_start.name, [Количество шагов];
GO

-- ------------------------------------------------------------
-- SP-Запрос 2: Шаблон "{1,3}"
-- Найти кратчайший путь от конкретного склада до точек выгрузки
-- глубиной от 1 до 3 шагов.
-- Путь: Warehouse -(Route)-> UnloadingPoint, 1–3 итерации.
-- Выводим всю цепочку точек и конечную точку.
-- ------------------------------------------------------------
PRINT N'=== SP-Запрос 2: Кратчайший путь складов до точек (шаблон {1,3}) ===';
SELECT
    w.name                                                              AS [Склад отправки],
    STRING_AGG(up.name, N' -> ') WITHIN GROUP (GRAPH PATH)             AS [Цепочка точек выгрузки],
    LAST_VALUE(up.name)          WITHIN GROUP (GRAPH PATH)             AS [Конечная точка],
    COUNT(up.name)               WITHIN GROUP (GRAPH PATH)             AS [Глубина пути]
FROM Warehouse      AS w
   , Route          FOR PATH AS r
   , UnloadingPoint FOR PATH AS up
WHERE MATCH(SHORTEST_PATH(w(-(r)->up){1,3}))
  AND w.name = N'Центральный распределительный склад'
ORDER BY [Глубина пути], [Конечная точка];
GO

-- ------------------------------------------------------------
-- SP-Запрос 3: Шаблон "+" с фильтрацией по конечному узлу
-- Найти кратчайший путь от любого склада до точки
-- "Портовый грузовой терминал" через цепочку
-- Warehouse → UnloadingPoint → Warehouse (Recommends).
-- ------------------------------------------------------------
PRINT N'=== SP-Запрос 3: Кратчайший путь до Портового терминала ===';
WITH PathCTE AS
(
    SELECT
        w_start.name                                                    AS [Начало],
        STRING_AGG(up.name, N' -> ') WITHIN GROUP (GRAPH PATH)         AS [Путь через точки],
        LAST_VALUE(up.name)          WITHIN GROUP (GRAPH PATH)         AS [Конец],
        COUNT(up.name)               WITHIN GROUP (GRAPH PATH)         AS [Шагов]
    FROM Warehouse      AS w_start
       , Route          FOR PATH AS r
       , UnloadingPoint FOR PATH AS up
    WHERE MATCH(SHORTEST_PATH(w_start(-(r)->up)+))
)
SELECT [Начало], [Путь через точки], [Шагов]
FROM PathCTE
WHERE [Конец] = N'Портовый грузовой терминал'
ORDER BY [Шагов], [Начало];
GO

----------------------------------------
--Запросы для powerBI для каждого ребра-
----------------------------------------

SELECT
    tr.truck_id                         AS [IdTruck],
    tr.plate_number                     AS [Фура],
    CONCAT(N'Truck', tr.truck_id)       AS [Truck image name],
    w.warehouse_id                      AS [IdWarehouse],
    w.name                              AS [Склад],
    CONCAT(N'Warehouse', w.warehouse_id) AS [Warehouse image name],
    a.assigned_date                     AS [Дата закрепления],
    a.assignment_type                   AS [Тип закрепления],
    a.is_active                         AS [Активно],
    a.notes                             AS [Примечание],
    IIF(a.is_active = 1, N'Действующее', N'Неактивное')
        AS [Статус привязки]
FROM Truck      AS tr,
     AssignedTo AS a,
     Warehouse  AS w
WHERE MATCH(tr-(a)->w);

SELECT
    w.warehouse_id                                AS [IdWarehouse],
    w.name                                        AS [Склад],
    CONCAT(N'Warehouse', w.warehouse_id)           AS [Warehouse image name],
    up.point_id                                   AS [IdUnloadingPoint],
    up.name                                       AS [Точка выгрузки],
    CONCAT(N'UnloadingPoint', up.point_id)         AS [UnloadingPoint image name],
    r.distance_km                                 AS [Дистанция (км)],
    r.avg_time_hrs                                AS [Среднее время (ч)],
    r.route_status                                AS [Статус маршрута],
    r.toll_cost_rub                               AS [Плата за проезд],
    r.priority                                    AS [Приоритет],
    r.opened_date                                 AS [Дата открытия],
    IIF(w.city = up.city, N'местный', N'междугородний')
        AS [Тип маршрута]
FROM Warehouse      AS w,
     Route          AS r,
     UnloadingPoint AS up
WHERE MATCH(w-(r)->up);


SELECT
    up.point_id                                   AS [IdUnloadingPoint],
    up.name                                       AS [Точка выгрузки],
    CONCAT(N'UnloadingPoint', up.point_id)         AS [UnloadingPoint image name],
    w.warehouse_id                                AS [IdWarehouse],
    w.name                                        AS [Рекомендованный склад],
    CONCAT(N'Warehouse', w.warehouse_id)           AS [Warehouse image name],
    rec.rec_date                                  AS [Дата рекомендации],
    rec.rec_status                                AS [Статус рекомендации],
    rec.rating                                    AS [Рейтинг],
    rec.comment                                   AS [Комментарий],
    IIF(up.city = w.city, N'местный склад', N'удалённый склад')
        AS [Тип расположения склада]
FROM UnloadingPoint AS up,
     Recommends     AS rec,
     Warehouse      AS w
WHERE MATCH(up-(rec)->w);

SELECT
    tr.truck_id                                     AS [IdTruck],
    tr.plate_number                                 AS [Номер фуры],
    CONCAT(N'Truck', tr.truck_id)                   AS [Truck image name],
    up.point_id                                     AS [IdUnloadingPoint],
    up.name                                         AS [Точка выгрузки],
    CONCAT(N'UnloadingPoint', up.point_id)           AS [UnloadingPoint image name],
    d.delivery_date                                 AS [Дата доставки],
    d.cargo_tons                                    AS [Вес груза (т)],
    d.cargo_type                                    AS [Тип груза],
    d.delivery_status                               AS [Статус доставки],
    d.distance_km                                   AS [Дистанция (км)],
    d.duration_hrs                                  AS [Продолжительность (ч)],
    IIF(d.delivery_status = N'completed', N'Успешная', N'Проблемная')
        AS [Итог доставки]
FROM Truck          AS tr,
     Delivers       AS d,
     UnloadingPoint AS up
WHERE MATCH(tr-(d)->up);

SELECT @@SERVERNAME