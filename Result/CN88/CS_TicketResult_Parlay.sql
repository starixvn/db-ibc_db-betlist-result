/*<info serverAlias="DBACC-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_TicketResult_Parlay]
	@RefNo	BIGINT
AS

/*
	Created: Kos@20190304
	Task: Get ticket result of a Parlay ticket
	DB: DBACC.bodb02
	Original: Age_BetList_SelMatchResultParlay
	Revisions:
		- 20190304@Kos: Create new [Redmine: 109230]
		- 20190807@Kos: Support PH AIO phase 4b [Redmine: #116865]
		- 20191014@Kos: Support Badminton AIO phase 2 [Redmine: #121610]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Sportsbook, Betradar Virtual Sports only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 27)

	DECLARE @tmpParlay TABLE(
		SportType			INT,
		LeagueId			INT,
		MatchId				INT,
		HomeId				INT,
		AwayId				INT,
		HtHomeScore			INT,
		HtAwayScore			INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
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
		BetType				SMALLINT,
		BetCheck			VARCHAR(50)
	)

	DECLARE @tmpResultDetail AS TABLE (
		MatchId				INT,
		ResourceId			VARCHAR(20),
		HomeValue			VARCHAR(20),
		AwayValue			VARCHAR(20),
		ResultStatusID		TINYINT,
		SettlementStatusID	TINYINT,
		OtherInfo			VARCHAR(50)
	)

	-- Bettrans range
	IF EXISTS (	SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
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
			m.GlobalShowTime AS kickofftime,
			m.eventdate,
			m.IsNeutral,
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
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			bm.bettype,
			bm.betcheck
		FROM
			(
				SELECT
					bm.matchid,
					bm.bettype,
					bm.betcheck
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo ) AS bm
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.MatchID = m.matchid AND d.ResourceID = '00'

		-- Get result detail
		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType IN (1, 2, 5))
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchID = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE ((p.SportType = 5			-- Tennis
					AND d.SettlementStatusID > 0
					AND CASE
							WHEN p.BetType <> 1324 THEN 2
							ELSE CASE
									WHEN p.BetType = 1324
										AND LEFT(d.ResourceID, 2) = LEFT(REPLACE(ISNULL(p.BetCheck, ''), '8', ''), 2) THEN 4
									ELSE 0
								END
						END = LEN(d.ResourceID))
				OR (p.SportType = 1			-- Soccer
					AND d.SettlementStatusID > 0
					AND (d.ResourceID NOT IN ('08', '09')		-- Return '08' FT Sequence, '09' 1H Sequence only if at least a goal/corner scored
						OR d.HomeValue LIKE '%a%'
						OR d.HomeValue LIKE '%h%')
					AND d.ResourceId LIKE f.ResourceID)
				OR (p.SportType = 2			-- Basketball
					AND (LEN(d.ResourceID) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceID LIKE f.ResourceID
							AND (p.BetType NOT IN (606, 607, 613, 617)
								OR d.ResourceID LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', ''))))))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 9)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetailOS AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchID = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType = 9		-- Badminton
				AND (LEN(d.ResourceID) IN (2, 4)
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', '')))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 43)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
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
				AND (LEN(d.ResourceID) = 2
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', '')))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 193)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
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
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
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
			m.GlobalShowTime AS kickofftime,
			m.eventdate,
			m.IsNeutral,
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
			bm.bettype,
			bm.betcheck
		FROM
			(
				SELECT
					bm.matchid,
					bm.bettype,
					bm.betcheck
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo ) AS bm
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.MatchID = m.matchid AND d.ResourceId = '00'

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType IN (1, 2, 5))
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail14 AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE ((p.SportType = 5			-- Tennis
					AND d.SettlementStatusID > 0
					AND CASE
							WHEN p.BetType <> 1324 THEN 2
							ELSE CASE
									WHEN p.BetType = 1324
										AND LEFT(d.ResourceID, 2) = LEFT(REPLACE(ISNULL(p.BetCheck, ''), '8', ''), 2) THEN 4
									ELSE 0
								END
						END = LEN(d.ResourceId))
				OR (p.SportType = 1			-- Soccer
					AND d.SettlementStatusID > 0
					AND (d.ResourceID NOT IN ('08', '09')		-- Return '08' FT Sequence, '09' 1H Sequence only if at least a goal/corner scored
						OR d.HomeValue LIKE '%a%'
						OR d.HomeValue LIKE '%h%')
					AND d.ResourceId LIKE f.ResourceID)
				OR (p.SportType = 2			-- Basketball
					AND (LEN(d.ResourceID) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceID LIKE f.ResourceID
							AND (p.BetType NOT IN (606, 607, 613, 617)
								OR d.ResourceID LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', ''))))))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 9)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetailOS14 AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.BetType AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType = 9		-- Badminton
				AND (LEN(d.ResourceID) IN (2, 4)
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', '')))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 43)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
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
				AND (LEN(d.ResourceID) = 2
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', '')))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 193)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
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
				FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			m.sporttype,
			m.leagueid,
			m.matchid,
			m.homeID,
			m.awayID,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			CASE
				WHEN m.sporttype = 162 THEN m.kickofftime
				ELSE m.GlobalShowTime
			END AS kickofftime,
			m.eventdate,
			m.IsNeutral,
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
			ISNULL(mr.refund, 0) IsRefund,
			ISNULL(mr.calrefund, 0) IsCalRefund,
			m.goalrecord,
			m.matchcode,
			ISNULL(mr.IsHTCal, 0) AS isHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			0 AS SettlementStatus,
			bm.Bettype,
			bm.Betcheck
		FROM
			(
				SELECT
					bm.matchId,
					bm.bettype,
					bm.betcheck
				FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo ) bm
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN bodb_Archive.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN bodb_Archive.dbo.ResultDetail_BK AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType IN (1, 2, 5))
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM bodb_Archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.Bettype AND d.ResourceId LIKE f.ResourceID
			WHERE ((p.SportType = 5			-- Tennis
					AND d.SettlementStatusID > 0
					AND CASE
							WHEN p.BetType <> 1324 THEN 2
							ELSE CASE
									WHEN p.BetType = 1324
										AND LEFT(d.ResourceId, 2) = LEFT(REPLACE(ISNULL(p.BetCheck, ''), '8', ''), 2) THEN 4
									ELSE 0
								END
						END = LEN(d.ResourceId))
				OR (p.SportType = 1			-- Soccer
					AND d.SettlementStatusID > 0
					AND (d.ResourceID NOT IN ('08', '09')		-- Return '08' FT Sequence, '09' 1H Sequence only if at least a goal/corner scored
						OR d.HomeValue LIKE '%a%'
						OR d.HomeValue LIKE '%h%')
					AND d.ResourceId LIKE f.ResourceID)
				OR (p.SportType = 2			-- Basketball
					AND (LEN(d.ResourceId) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND (p.BetType NOT IN (606, 607, 613, 617)
								OR d.ResourceId LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', ''))))))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 9)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM bodb_Archive.dbo.ResultDetailOS_bk AS d WITH (NOLOCK)
				INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = p.Bettype AND d.ResourceId LIKE f.ResourceID
			WHERE p.SportType = 9		-- Badminton
				AND (LEN(d.ResourceID) IN (2, 4)
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', '')))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 43)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
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
				AND (LEN(d.ResourceID) = 2
					OR (d.SettlementStatusID > 0
						AND d.ResourceID LIKE f.ResourceID
						AND d.ResourceID LIKE '%' + REPLACE(ISNULL(p.BetCheck, ''), '8', '')))
		END

		IF EXISTS (SELECT 1 FROM @tmpParlay WHERE SportType = 193)
		BEGIN
			INSERT INTO @tmpResultDetail
			SELECT
				d.MatchId,
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

	SELECT DISTINCT * FROM @tmpParlay
	ORDER BY LeagueId ASC,
		BetType ASC,
		EventDate ASC,
		MatchCode ASC

	-----> Order [LeagueID, Bettype] to group choices in Set x game y together in the same LeagueId.

	SELECT DISTINCT * FROM @tmpResultDetail
	ORDER BY MatchId ASC,
		ResourceId ASC
END
GO



GRANT EXECUTE ON [dbo].[CS_TicketResult_Parlay] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[CS_TicketResult_Parlay] TO [bodbDownlineNetView]
GO
