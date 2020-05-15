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

	RETURN
END




GO 
GRANT SELECT ON [dbo].[f_ResourceBettype] TO [bodbDownlineNet]
GO 
GRANT SELECT ON [dbo].[f_ResourceBettype] TO [bodbDownlineNetView]
GO
