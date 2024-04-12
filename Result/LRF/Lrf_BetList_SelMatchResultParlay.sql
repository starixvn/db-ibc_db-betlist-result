/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SelMatchResultParlay]
	@RefNo	BIGINT
AS

/*
	Created: Henry@20101210
	Task: Get Parlay ticket result
	DB: DBACC.bodb02
	Original: Age_BetList_SelMatchResultParlay
	Revisions:
		- 20110907@Sophia: Add column IsHTCal, calculate for Pending result
		- 20110927@Henry: Add more columns
		- 20131017@Jim: Turn to use GlobalShowTime for display the Kick-off-Time
		- 20141021@Jim: Support to show Sportting Solution data detail
		- 20140407@Sophia: Support BetRadar
		- 20161007@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161011@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
		- 20170418@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170613@Kos: Get data from DBARC.bodb_Archive.dbo.match_remark for bk range instead [#Redmine: 78212]
		- 20170623@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20180103@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180307@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20181015@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
					- Move eventstatus data transform to web (no change for Tennis)
		- 20181018@Kos: Support E-Sports 2 [#Redmine: 100721]
		- 20190325@Kos: Hotfix - Bet ID contain '8' [Redmine: #112376]
		- 20190814@Kos: Support PH AIO phase 4b [Redmine: #118300]
		- 20191028@Kos: Move to DBACC [Redmine: #122267]
		- 20191107@Kos: Support Badminton AIO phase 2 [Redmine: #120336]
		- 20191223@Kos: Support PH AIO phase 5 [Redmine: #126005]
		- 20200507@Kos: Support E-Sports phase 3 [Redmine: #132386]
		- 20210223@Kos: Support Cricket AIO [Redmine: #150386]
		- 20210630@Kos: Support Beach Volleyball [Redmine: #157296]
		- 20220315@Kos: Support Cricket phase 2 [Redmine: #168034]
		- 20220325@Kos: Extend OtherInfo length [Redmine: #168034]
		- 20220328@Kos: Fix length issue [Redmine: #168034]
		- 20220623@Kos: Support more map for E-Sports [Redmine: #174251]
		- 20220722@Kos: Support Volleyball AIO [Redmine: #175143]
		- 20230321@Kos: Change Display HT Score for some Special League of Soccer [Redmine: #181331]
		- 20231024@Kos: Support Basketball Instant Settlement [Redmine: #194323]
		- 20231221@Kos: Switch to use ResultDetailOS for Bandy [Redmine: #198714]
		- 20240412@Kos: Change display for Last Series child match [Redmine: #202484]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Sportsbook and Virtual Sports 2 only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 27)

	DECLARE @tmpParlay TABLE (
		SportType			INT,
		LeagueId			INT,
		MatchId				INT,
		HomeId				INT,
		AwayId				INT,
		HtHomeScore			INT,
		HtAwayScore			INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		KickOffTime			DATETIME,
		EventDate			DATETIME,
		IsNeutral			BIT,
		BetStatus			VARCHAR(50),
		EventStatus			VARCHAR(15),
		IsRefund			BIT,
		IsCalRefund			BIT,
		GoalRecord			VARCHAR(50),
		MatchCode			VARCHAR(50),
		IsHTCal				BIT,
		Calculate			BIT,
		SettlementStatus	TINYINT,
		NoHTScore			BIT,
		MainType			TINYINT,
		SubType				SMALLINT,
		BetType				SMALLINT,
		BetCheck			VARCHAR(50),
		TransDesc			NVARCHAR(1000)
	)

	DECLARE @tmpResultDetail TABLE (
		MatchId				INT,
		BetType				SMALLINT,
		ResourceId			VARCHAR(20),
		HomeValue			VARCHAR(20),
		AwayValue			VARCHAR(20),
		ResultStatusId		TINYINT,
		SettlementStatusId	TINYINT,
		OtherInfo			VARCHAR(2000)
	)

	DECLARE @SubTicket AS TABLE (
		MatchId			INT,
		SportType		SMALLINT,
		ChildMatchType	TINYINT,
		ParentId		INT,
		BetType			SMALLINT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000)
	)

	-- Bettrans range
	IF EXISTS (	SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @SubTicket
		SELECT
			bm.matchid,
			m.sporttype,
			m.ChildMatchType,
			m.ParentID,
			bm.bettype,
			bm.betcheck,
			bm.transdesc
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = bm.matchid
		WHERE bm.refno = @RefNo
	END

	-- Bettrans14 range
	IF EXISTS (	SELECT 1
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @SubTicket
		SELECT
			bm.matchid,
			m.sporttype,
			m.ChildMatchType,
			m.ParentID,
			bm.bettype,
			bm.betcheck,
			bm.transdesc
		FROM dbo.bettransm14 AS bm WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = bm.matchid
		WHERE bm.refno = @RefNo
			AND NOT EXISTS (SELECT 1 FROM @SubTicket WHERE matchid = bm.matchid )
	END

	-- Bettrans_bk range
	IF EXISTS (	SELECT 1
				FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @SubTicket
		SELECT
			bm.matchid,
			m.sporttype,
			m.ChildMatchType,
			m.ParentID,
			bm.bettype,
			bm.betcheck,
			bm.transdesc
		FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = bm.matchid
		WHERE bm.refno = @RefNo
			AND NOT EXISTS (SELECT 1 FROM @SubTicket WHERE matchid = bm.matchid )
	END

	-- Switch to use parent match for Cricket child match (ChildMatchType = 200)
	UPDATE @SubTicket
	SET MatchId = ParentId
	WHERE SportType = 50 AND ChildMatchType = 200

	-- Bettrans range
	IF EXISTS ( SELECT 1
				FROM @SubTicket AS bm
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = bm.MatchId)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			m.sporttype,
			m.leagueid,
			m.matchid,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			CASE
				WHEN m.sporttype <> 161 THEN m.GlobalShowTime
				ELSE m.kickofftime
			END AS KickOffTime,
			m.eventdate,
			m.IsNeutral,
			m.betstatus,
			CASE m.sporttype
				WHEN 5 THEN
					CASE ISNULL(d.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund'
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS EventStatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			m.goalrecord,
			m.matchcode,
			ISNULL(mr.IsHTCal, 0) AS isHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			ISNULL(mr.NoHTScore, 0) AS NoHTScore,
			ISNULL(mr.MainType, 0) AS MainType,
			ISNULL(mr.SubType, 0) AS SubType,
			bm.BetType,
			bm.BetCheck,
			bm.TransDesc
		FROM
			@SubTicket AS bm
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'

		-- Get result detail
		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType IN (1, 2, 5))
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchID,
				p.BetType,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchID = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) f
					ON f.Bettype = p.Bettype AND d.ResourceId LIKE f.ResourceID
			WHERE ((p.SportType = 5								-- Tennis
					AND d.SettlementStatusID > 0
					AND CASE
							WHEN p.BetType NOT IN (1324) THEN 2
							ELSE CASE
								WHEN p.BetType IN (1324)
									AND LEFT(d.ResourceID, 2) = LEFT(REPLACE(ISNULL(p.BetCheck, ''), '8', ''), 2) THEN 4
								ELSE 0
							END
						END = LEN(d.ResourceId))
				OR (p.SportType = 1								-- Soccer
					AND d.SettlementStatusID > 0
					AND (d.ResourceId NOT IN ('08', '09')		-- Return '08' FT Sequence, '09' 1H Sequence only if at least a goal/corner scored
						OR d.HomeValue LIKE '%a%'
						OR d.HomeValue LIKE '%h%')
					AND d.ResourceID LIKE f.ResourceID
					AND (p.BetType NOT IN (395, 385, 384, 383, 382, 381)
						OR d.ResourceID LIKE '%' + CASE
														WHEN p.BetType = 395 THEN RIGHT(p.BetCheck, 2)
														WHEN p.BetType IN (385, 384, 383, 382, 381) THEN RIGHT(p.BetCheck, LEN(p.BetCheck) - 1)
														ELSE ''
													END))
				OR (p.SportType = 2								-- Basketball
					AND (LEN(d.ResourceId) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND (p.BetType NOT IN (606, 607, 613, 617)
								OR d.ResourceId LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', ''))))))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType IN (6, 9, 45, 50, 58))		-- Volleyball, Badminton, Cricket, Beach Volleyball, Bandy
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				p.BetType,
				d.ResourceId,
				CASE
					WHEN p.BetType IN (9662, 9664, 9666) AND d.ResourceId LIKE '9662%' THEN p.TransDesc
					WHEN p.BetType IN (9663, 9665, 9667) AND d.ResourceId LIKE '9663%' THEN p.TransDesc
					ELSE d.HomeValue
				END AS HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetailOS AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchID = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType IN (6, 9, 45, 50, 58)
				AND (LEN(d.ResourceID) = 2
					OR (LEN(d.ResourceID) = 4 AND p.SportType IN (9, 45))
					OR (p.SportType = 6 AND d.ResourceId LIKE '010%')
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + CASE
														WHEN LEN(ISNULL(p.BetCheck, '')) <= 1 THEN ''
														WHEN p.BetType IN (3903, 3904, 3905) THEN RIGHT(p.BetCheck, LEN(p.BetCheck) - 1) + '15'
														ELSE RIGHT(p.BetCheck, LEN(p.BetCheck) - 1)
													END))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 43)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				p.BetType,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetailES AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchID = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType = 43		-- E-Sports
				AND (d.ResourceID = '00'
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + CASE
														WHEN p.BetType = 9001 AND p.BetCheck LIKE '80%' THEN 'M' + RIGHT(p.BetCheck, 1)
														ELSE RIGHT(p.BetCheck, LEN(p.BetCheck) - 1) 
													END
												+ CASE
														WHEN p.BetType = 9101 THEN '01'
														WHEN p.BetType = 9102 THEN '02'
														WHEN p.BetType = 9103 THEN '03'
														WHEN p.BetType = 9104 THEN '04'
														WHEN p.BetType = 9105 THEN '05'
														WHEN p.BetType = 9106 THEN '06'
														WHEN p.BetType = 9107 THEN '07'
														WHEN p.BetType = 9108 THEN '08'
														WHEN p.BetType = 9109 THEN '09'
														WHEN p.BetType = 9110 THEN '10'
														WHEN p.BetType = 9111 THEN '15'
														WHEN p.BetType = 9112 THEN '20'
														ELSE ''
													END))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 193)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				p.BetType,
				d.ResourceId,
				d.Custom1 AS HomeValue,
				d.Custom2 AS AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail3rd AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchID = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType = 193
				AND d.SettlementStatusID > 0
				AND (d.ResourceID IN ('00', '01')
					OR (d.ResourceID LIKE f.ResourceID
						AND (p.BetType <> 2809
							OR d.ResourceID LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', ''))))
		END
	END

	-- Bettrans14 range
	IF EXISTS (	SELECT 1
				FROM @SubTicket AS bm
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = bm.MatchId)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			m.sporttype,
			m.leagueid,
			m.matchid,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			CASE
				WHEN m.sporttype <> 161 THEN m.GlobalShowTime
				ELSE m.kickofftime
			END AS KickOffTime,
			m.eventdate,
			m.isNeutral,
			m.betstatus,
			CASE m.Sporttype
				WHEN 5 THEN
					CASE ISNULL(d.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund' 
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS EventStatus,
			ISNULL(mr.refund, 0) IsRefund,
			ISNULL(mr.calrefund, 0) IsCalRefund,
			m.goalrecord,
			m.matchcode,
			ISNULL(mr.IsHTCal, 0) AS isHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			0 AS SettlementStatus,
			ISNULL(mr.NoHTScore, 0) AS NoHTScore,
			ISNULL(mr.MainType, 0) AS MainType,
			ISNULL(mr.SubType, 0) AS SubType,
			bm.BetType,
			bm.BetCheck,
			bm.TransDesc
		FROM
			@SubTicket AS bm
			INNER JOIN dbo.match14 AS m WITH(NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH(NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType IN (1, 2, 5))
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				p.BetType,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail14 AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE ((p.SportType = 5								-- Tennis
					AND d.SettlementStatusID > 0
					AND CASE
							WHEN p.BetType NOT IN (1324) THEN 2
							ELSE CASE
								WHEN p.BetType IN (1324)
									AND LEFT(d.ResourceID, 2) = LEFT(REPLACE (ISNULL(p.BetCheck, ''), '8', ''), 2) THEN 4
								ELSE 0
							END
						END = LEN(d.ResourceId))
				OR (p.SportType = 1								-- Soccer
					AND d.SettlementStatusID > 0
					AND (d.ResourceId NOT IN ('08', '09')		-- Return '08' FT Sequence, '09' 1H Sequence only if at least a goal/corner scored
						OR d.HomeValue LIKE '%a%'
						OR d.HomeValue LIKE '%h%')
					AND d.ResourceId LIKE f.ResourceID
					AND (p.BetType NOT IN (395, 385, 384, 383, 382, 381)
						OR d.ResourceID LIKE '%' + CASE
														WHEN p.BetType = 395 THEN RIGHT(p.BetCheck, 2)
														WHEN p.BetType IN (385, 384, 383, 382, 381) THEN RIGHT(p.BetCheck, LEN(p.BetCheck) - 1)
														ELSE ''
													END))
				OR (p.SportType = 2								-- Basketball
					AND (LEN(d.ResourceId) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND (p.BetType NOT IN (606, 607, 613, 617)
								OR d.ResourceId LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', ''))))))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType IN (6, 9, 45, 50, 58))		-- Volleyball, Badminton, Cricket, Beach Volleyball, Bandy
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				p.BetType,
				d.ResourceId,
				CASE
					WHEN p.BetType IN (9662, 9664, 9666) AND d.ResourceId LIKE '9662%' THEN p.TransDesc
					WHEN p.BetType IN (9663, 9665, 9667) AND d.ResourceId LIKE '9663%' THEN p.TransDesc
					ELSE d.HomeValue
				END AS HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetailOS14 AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType IN (6, 9, 45, 50, 58)
				AND (LEN(d.ResourceID) = 2
					OR (LEN(d.ResourceID) = 4 AND p.SportType IN (9, 45))
					OR (p.SportType = 6 AND d.ResourceId LIKE '010%')
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + CASE
														WHEN LEN(ISNULL(p.BetCheck, '')) <= 1 THEN ''
														WHEN p.BetType IN (3903, 3904, 3905) THEN RIGHT(p.BetCheck, LEN(p.BetCheck) - 1) + '15'
														ELSE RIGHT(p.BetCheck, LEN(p.BetCheck) - 1)
													END))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 43)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				p.BetType,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetailES14 AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType = 43		-- E-Sports
				AND (d.ResourceID = '00'
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + CASE
														WHEN p.BetType = 9001 AND p.BetCheck LIKE '80%' THEN 'M' + RIGHT(p.BetCheck, 1)
														ELSE RIGHT(p.BetCheck, LEN(p.BetCheck) - 1) 
													END
												+ CASE
													WHEN p.BetType = 9101 THEN '01'
													WHEN p.BetType = 9102 THEN '02'
													WHEN p.BetType = 9103 THEN '03'
													WHEN p.BetType = 9104 THEN '04'
													WHEN p.BetType = 9105 THEN '05'
													WHEN p.BetType = 9106 THEN '06'
													WHEN p.BetType = 9107 THEN '07'
													WHEN p.BetType = 9108 THEN '08'
													WHEN p.BetType = 9109 THEN '09'
													WHEN p.BetType = 9110 THEN '10'
													WHEN p.BetType = 9111 THEN '15'
													WHEN p.BetType = 9112 THEN '20'
													ELSE ''
												END))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 193)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				p.BetType,
				d.ResourceId,
				d.Custom1 AS HomeValue,
				d.Custom2 AS AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail3rd14 AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchID = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType = 193
				AND d.SettlementStatusID > 0
				AND (d.ResourceID IN ('00', '01')
					OR (d.ResourceID LIKE f.ResourceID
						AND (p.BetType <> 2809
							OR d.ResourceID LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', ''))))
		END
	END

	-- Bettrans_bk range
	IF EXISTS (	SELECT 1
				FROM @SubTicket AS bm
					INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = bm.MatchId)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			m.sporttype,
			m.LeagueID,
			m.matchid,
			m.homeID,
			m.awayID,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			CASE
				WHEN m.sporttype <> 161 THEN m.GlobalShowTime
				ELSE m.kickofftime
			END AS kickofftime,
			m.eventdate,
			m.isNeutral,
			m.betstatus,
			CASE m.Sporttype
				WHEN 5 THEN
					CASE ISNULL(d.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund' 
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS eventstatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			m.goalrecord,
			m.matchcode,
			ISNULL(mr.IsHTCal, 0) AS isHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			0 AS SettlementStatus,
			ISNULL(mr.NoHTScore, 0) AS NoHTScore,
			ISNULL(mr.MainType, 0) AS MainType,
			ISNULL(mr.SubType, 0) AS SubType,
			bm.BetType,
			bm.BetCheck,
			bm.TransDesc
		FROM
			@SubTicket AS bm
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN bodb_Archive.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN bodb_Archive.dbo.ResultDetail_bk AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType IN (1, 2, 5))
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				p.BetType,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM bodb_Archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE ((p.SportType = 5								-- Tennis
					AND d.SettlementStatusID > 0
					AND CASE
							WHEN p.BetType NOT IN (1324) THEN 2
							ELSE CASE
								WHEN p.BetType IN (1324)
									AND LEFT(d.ResourceID, 2) = LEFT(REPLACE (ISNULL(p.BetCheck, ''), '8', ''), 2) THEN 4
								ELSE 0
							END
						END = LEN(d.ResourceId))
				OR (p.SportType = 1								-- Soccer
					AND d.SettlementStatusID > 0
					AND (d.ResourceId NOT IN ('08', '09')		-- Return '08' FT Sequence, '09' 1H Sequence only if at least a goal/corner scored
						OR d.HomeValue LIKE '%a%'
						OR d.HomeValue LIKE '%h%')
					AND d.ResourceId LIKE f.ResourceID
					AND (p.BetType NOT IN (395, 385, 384, 383, 382, 381)
						OR d.ResourceId LIKE '%' + CASE
														WHEN p.BetType = 395 THEN RIGHT(p.BetCheck, 2)
														WHEN p.BetType IN (385, 384, 383, 382, 381) THEN RIGHT(p.BetCheck, LEN(p.BetCheck) - 1)
														ELSE ''
													END))
				OR (p.SportType = 2								-- Basketball
					AND (LEN(d.ResourceId) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND (p.BetType NOT IN (606, 607, 613, 617)
								OR d.ResourceId LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', ''))))))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType IN (6, 9, 45, 50, 58))		-- Volleyball, Badminton, Cricket, Beach Volleyball, Bandy
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				p.BetType,
				d.ResourceId,
				CASE
					WHEN p.BetType IN (9662, 9664, 9666) AND d.ResourceId LIKE '9662%' THEN p.TransDesc
					WHEN p.BetType IN (9663, 9665, 9667) AND d.ResourceId LIKE '9663%' THEN p.TransDesc
					ELSE d.HomeValue
				END AS HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM bodb_Archive.dbo.ResultDetailOS_bk AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.Bettype AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType IN (6, 9, 45, 50, 58)
				AND (LEN(d.ResourceID) = 2
					OR (LEN(d.ResourceID) = 4 AND p.SportType IN (9, 45))
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + CASE
														WHEN LEN(ISNULL(p.BetCheck, '')) <= 1 THEN ''
														WHEN p.BetType IN (3903, 3904, 3905) THEN RIGHT(p.BetCheck, LEN(p.BetCheck) - 1) + '15'
														ELSE RIGHT(p.BetCheck, LEN(p.BetCheck) - 1)
													END))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 43)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				p.BetType,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM bodb_Archive.dbo.ResultDetailES_bk AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.Bettype AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType = 43		-- E-Sports
				AND (d.ResourceID = '00'
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + CASE
														WHEN p.BetType = 9001 AND p.BetCheck LIKE '80%' THEN 'M' + RIGHT(p.BetCheck, 1)
														ELSE RIGHT(p.BetCheck, LEN(p.BetCheck) - 1)
													END
												+ CASE
													WHEN p.BetType = 9101 THEN '01'
													WHEN p.BetType = 9102 THEN '02'
													WHEN p.BetType = 9103 THEN '03'
													WHEN p.BetType = 9104 THEN '04'
													WHEN p.BetType = 9105 THEN '05'
													WHEN p.BetType = 9106 THEN '06'
													WHEN p.BetType = 9107 THEN '07'
													WHEN p.BetType = 9108 THEN '08'
													WHEN p.BetType = 9109 THEN '09'
													WHEN p.BetType = 9110 THEN '10'
													WHEN p.BetType = 9111 THEN '15'
													WHEN p.BetType = 9112 THEN '20'
													ELSE ''
												END))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 193)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				p.BetType,
				d.ResourceId,
				d.Custom1 AS HomeValue,
				d.Custom2 AS AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM bodb_Archive.dbo.ResultDetail3rd_BK AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchID = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType = 193
				AND d.SettlementStatusID > 0
				AND (d.ResourceID IN ('00', '01')
					OR (d.ResourceID LIKE f.ResourceID
						AND (p.BetType <> 2809
							OR d.ResourceID LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', ''))))
		END
	END

	-- Get data
	SELECT DISTINCT * FROM @tmpParlay
	ORDER BY LeagueId ASC,
		BetType ASC,
		EventDate ASC,
		MatchCode ASC

	SELECT DISTINCT * FROM @tmpResultDetail
	ORDER BY MatchId ASC,
		ResourceId ASC
END
GO
