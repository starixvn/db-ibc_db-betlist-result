ALTER FUNCTION [dbo].[f_ResourceBettype]
(
)
RETURNS @ResourceBettype TABLE (SportType SMALLINT, ResultGroup TINYINT, ResultGroupDesc VARCHAR(500), BetType SMALLINT, ResourceID VARCHAR(20))
AS

/*
	Created: 20150401@Sophia
	Task : Matrix of Bettype vs ResourceID, for matching with betId/ betcheck of ticket
			Store only Bettypes of BetRadar which use Table ResultDetail 
	DB: DBAGE.bodb02, DBEXT.bodb02
	Revisions:
		- 20160505@Kos: Support Fast Market [#Redmine: 56589]
		- 20160829@Kos: Support PH All In One phase 2b [#Redmine: 62882]
		- 20170323@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170802@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
		- 20171012@Kos: Support PH AIO Phase 3 [Redmine: #82403]
		- 20180320@Kos: Support Fast Market 2 [Redmine: #90708]
*/

BEGIN
	-- 1. BetRadar (Soccer)
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 1, 'Goals', 176, '176')

	---
	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 2, 'Goal Record', 180, '180%')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 2, 'Goal Record', 22, '160%')

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
	VALUES (1, 1, 'Goals', 422, '08')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 1, 'Goals', 423, '08')

	INSERT INTO @ResourceBettype (Sporttype, ResultGroup, ResultGroupDesc, Bettype, ResourceID)
	VALUES (1, 1, 'Goals', 425, '08')

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

	RETURN
END




GO 
GRANT SELECT ON [dbo].[f_ResourceBettype] TO [bodbDownlineNet]
GO 
GRANT SELECT ON [dbo].[f_ResourceBettype] TO [bodbDownlineNetView]
GO
