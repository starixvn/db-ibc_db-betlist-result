/*<info serverAlias="DBAGE-bodb02,DBEXT-bodb02,DBACC-bodb02" selecters="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[f_ResourceBettype]
(
)
RETURNS @ResourceBettype TABLE (SportType SMALLINT, ResultGroup TINYINT, ResultGroupDesc VARCHAR(500), BetType SMALLINT, ResourceID VARCHAR(20))
AS

/*
	Created: 20150401@Sophia
	Task: Matrix of Bettype vs ResourceID, support to show result popup of SB ticket
	DB: DBAGE.bodb02, DBEXT.bodb02, DBACC.bodb02

	Revisions:
		- 20160505@Kos: Support Fast Market [#Redmine: 56589]
		- 20160829@Kos: Support PH All In One phase 2b [#Redmine: 62882]
		- 20170323@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170802@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
		- 20171012@Kos: Support PH AIO Phase 3 [Redmine: #82403]
		- 20180320@Kos: Support Fast Market 2 [Redmine: #90708]
		- 20180410@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20180906@Kos: Support E-Sports phase 2 [Redmine: #101047]
		- 20190801@Kos: Support PH AIO phase 4b [Redmine: #115235]
					- Change for "Next Goal" [Redmine: #115235]
		- 20191014@Kos: Support Badminton AIO phase 2 [Redmine: #120381]
		- 20191204@Kos: Show Instant Calculation Result for Corner Bettypes [Redmine: #124682]
		- 20191220@Kos: Support PH AIO phase 5 [Redmine: #124455]
		- 20200507@Kos: Support E-Sports phase 3 [Redmine: #132386]
		- 20200515@Kos: Support PH AIO phase 5.1 [Redmine: #132770]
		- 20201006@Razor: Support Time Machine Over/Under [Redmine: #141998]
		- 20210223@Kos: Support Cricket AIO [Redmine: #148962]
		- 20210414@Razor: Support Time Machine HDP [Redmine: #152749]
		- 20210823@Razor: Support Cricket AIO 1.2 [Redmine: #160409]
		- 20210922@Razor: Support Cricket AIO 1.2 - add bettype 9442, 9443 [Redmine: #160409]
		- 20220120@Razor: Support E-Sports phase 4 [Redmine: #166326]
*/

BEGIN
	-- 1. BetRadar (Soccer)
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 1, 'Goals', 176, '176')

	---
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 2, 'Goal Record', 180, '180%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 2, 'Goal Record', 160, '160%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 2, 'Goal Record', 164, '164%')

	---
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 3, 'Goal Time', 192, '192')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 3, 'Goal Time', 193, '193')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 3, 'Goal Time', 169, '169%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 3, 'Goal Time', 455, '455')

	---
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 4, 'Goal Scorer', 217, '217')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 4, 'Goal Scorer', 216, '216%')

	---
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 200, '05')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 201, '05')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 202, '05')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 203, '05')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 204, '05')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 205, '05')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 194, '04')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 195, '04')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 196, '04')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 197, '04')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 198, '04')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 199, '04')

	---
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 6, 'First/Last Corners', 207, '207')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 6, 'First/Last Corners', 209, '209')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 6, 'First/Last Corners', 206, '206')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 6, 'First/Last Corners', 208, '208')

	---
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 7, 'Player Sent Off', 211, '211')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 7, 'Player Sent Off', 210, '210')

	---
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 8, 'Home/Away - Player Sent Off', 213, '213')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 8, 'Home/Away - Player Sent Off', 215, '215')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 8, 'Home/Away - Player Sent Off', 212, '212')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 8, 'Home/Away - Player Sent Off', 214, '214')

	---
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 9, 'Special', 173, '173')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 9, 'Special', 174, '174')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 9, 'Special', 135, '135')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 9, 'Special', 175, '175')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 9, 'Special', 168, '168')

	-- 2. Sporting Solution
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 1301, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 1302, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 1303, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 1305, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 1306, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 1308, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 1311, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 1312, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 1316, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 1317, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 1318, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 153, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 154, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 155, '0%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (5, 1, 'Set X', 156, '0%')

	-- 3. PH All In One phase 2b
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 422, '08')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 423, '08')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 425, '08')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 1, 'Goals', 424, '424')

	-- 4. Fast Market
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 10, 'Fast Market', 221, '221%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 10, 'Fast Market', 222, '222%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 10, 'Fast Market', 222, '221CNT%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 10, 'Fast Market', 223, '223%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 10, 'Fast Market', 224, '224%')
	
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 10, 'Fast Market', 225, '225%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 10, 'Fast Market', 226, '226%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 10, 'Fast Market', 227, '227%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 10, 'Fast Market', 228, '228%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 10, 'Fast Market', 229, '229%')

	-- 5. Basketball AIO
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (2, 1, 'Basketball AIO', 604, '604')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (2, 1, 'Basketball AIO', 605, '605')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (2, 1, 'Basketball AIO', 606, '606%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (2, 1, 'Basketball AIO', 607, '607%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (2, 1, 'Basketball AIO', 613, '613%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (2, 1, 'Basketball AIO', 617, '617%')

	-- 6. Betradar Virtual Basketball
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (193, 1, 'Betradar Virtual Basketball', 2809, '2809%')

	-- 7. E-Sports 2.0
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	SELECT 43, 1, 'E-Sports', 9002, '9002%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9003, '9002%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9004, '9002%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9005, '9002%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9006, '9006%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9007, '9007%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9008, '9008%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9009, '9008%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9010, '9008%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9078, '9008%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9011, '9011%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9012, '9012%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9013, '9012%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9014, '9012%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9079, '9012%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9015, '9015%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9016, '9016%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9017, '9017%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9018, '9018%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9019, '9018%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9020, '9018%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9080, '9018%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9021, '9021%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9022, '9022%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9023, '9023%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9024, '9024%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9025, '9024%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9026, '9024%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9081, '9024%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9027, '9027%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9028, '9028%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9029, '9028%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9030, '9028%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9082, '9028%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9031, '9031%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9032, '9032%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9033, '9033%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9034, '9034%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9035, '9034%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9036, '9034%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9083, '9034%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9037, '9037%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9038, '9038%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9039, '9039%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9040, '9040%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9041, '9040%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9042, '9040%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9084, '9040%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9043, '9043%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9044, '9044%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9045, '9045%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9046, '9046%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9047, '9046%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9048, '9046%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9085, '9046%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9049, '9049%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9050, '9050%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9051, '9051%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9052, '9052%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9053, '9052%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9054, '9052%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9086, '9052%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9055, '9055%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9056, '9056%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9057, '9057%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9058, '9058%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9059, '9059%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9060, '9059%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9061, '9059%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9062, '9062%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9063, '9063%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9064, '9064%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9065, '9065%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9066, '9066%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9076, '9066%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9067, '9067%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9068, '9068%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9069, '9069%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9070, '9069%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9071, '9069%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9077, '9069%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9072, '9072%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9073, '9073%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9074, '9074%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9075, '9075%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9087, '9087%'
	-- 7.1 E-Sports 4.0
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	SELECT 43, 1, 'E-Sports', 9089, '9089%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9090, '9090%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9091, '9091%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9092, '9091%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9095, '9091%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9096, '9091%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9093, '9093%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9094, '9093%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9097, '9093%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9098, '9093%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9099, '9002%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9100, '9002%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9101, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9102, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9103, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9104, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9105, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9106, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9107, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9108, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9109, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9110, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9111, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9112, '9101%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9113, '9113%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9114, '9114%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9115, '9115%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9116, '9115%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9117, '9115%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9118, '9115%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9119, '9115%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9120, '9115%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9121, '9121%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9122, '9122%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9123, '9123%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9124, '9124%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9125, '9125%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9126, '9126%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9127, '9127%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9128, '9128%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9129, '9129%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9130, '9130%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9131, '9131%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9132, '9132%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9133, '9133%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9134, '9134%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9135, '9135%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9136, '9136%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9137, '9137%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9138, '9138%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9139, '9139%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9140, '9140%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9141, '9141%'	UNION ALL
	SELECT 43, 1, 'E-Sports', 9142, '9142%'

	-- 8. PH All In One phase 4b & Next Goal
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 486, '08')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 486, '486%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 488, '08')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 488, '488')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 490, '08')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 490, '490')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 491, '08')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 487, '09')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 487, '487%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 489, '09')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 489, '489')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 490, '09')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 492, '09')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 479, '479')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 5, 'Corners', 481, '481')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 0, 'None', 22, '08')

	-- 9. Badminton All In One phase 2
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (9, 1, 'Badminton AIO', 712, '712%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (9, 1, 'Badminton AIO', 713, '713%')

	-- 10. Extra Time (PH All In One phase 5)
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 11, 'Extra Time', 396, '08')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 11, 'Extra Time', 395, '395%')

	-- 11. Penalty Shootout (PH All In One phase 5)
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 393, '393')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 391, '391')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 390, '390')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 387, '387')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 386, '386')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 385, '385%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 384, '384%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 383, '383%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 382, '382%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 382, '381%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 381, '382%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 381, '381%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 12, 'Penalty Shootout', 376, '376')

	-- 12. Cricket AIO
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	SELECT 50, 13, 'Cricket AIO', 9400, '9400'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9540, '9400'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9401, '9401'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9410, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9502, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9547, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9416, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9508, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9553, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9412, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9504, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9549, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9418, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9510, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9555, '94101%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9506, '94102%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9551, '94102%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9414, '94102%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9420, '94102%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9512, '94102%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9557, '94102%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9411, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9503, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9548, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9417, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9509, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9554, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9413, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9505, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9550, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9419, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9511, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9556, '94111%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9415, '94112%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9507, '94112%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9552, '94112%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9421, '94112%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9513, '94112%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9558, '94112%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9422, '94221%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9423, '94231%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9428, '94281%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9514, '94281%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9559, '94281%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9430, '94281%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9516, '94281%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9561, '94281%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9432, '94282%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9518, '94282%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9563, '94282%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9429, '94291%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9515, '94291%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9560, '94291%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9431, '94291%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9517, '94291%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9562, '94291%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9433, '94292%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9519, '94292%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9564, '94292%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9434, '94341%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9436, '94341%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9438, '94342%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9435, '94351%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9437, '94351%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9439, '94352%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9446, '9446'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9527, '9446'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9566, '9446'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9447, '9447'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9528, '9447'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9567, '9447'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9449, '9449'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9569, '9449'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9450, '9450'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9530, '9450'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9570, '9450'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9452, '9452'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9572, '9452'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9453, '9453'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9573, '9453'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9454, '94541'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9532, '94541'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9574, '94541'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9455, '94551'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9533, '94551'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9575, '94551'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9460, '94601'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9580, '94601'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9461, '94611'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9581, '94611'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9484, '94841%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9485, '94851%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9490, '94901%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9491, '94911%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9607, '94841%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9608, '94851%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9609, '94841%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9610, '94851%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9611, '94842%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9612, '94852%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9613, '94901%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9614, '94911%'	UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9442, '9442'		UNION ALL
	SELECT 50, 13, 'Cricket AIO', 9443, '9443'
	
	RETURN
END
