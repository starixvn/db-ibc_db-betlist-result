ALTER PROCEDURE [dbo].[Age_BetList_SelMatchResultParlay]
	@RefNo	BIGINT
AS

/*
	Created: nqminh@20090402
	Task: Select MixParlay result
	DB: DBAGE.bodb02
	Original: Age_BetList_SelMatchResultParlay
	Revisions:
		- 20091202@Jamie: Results for Future Mix Parlay
		- 20100123@Henry: Grant execute to Accounting site
		- 20110819@Johnson: Add column kickofftime
		- 20110831@Johnson: Correct event status when refund ticket
		- 20110907@Sophia: Add column IsHTCal, calculate for Pending Status.
		- 20111003@Sophia: Add column IsPending Pending Status.
		- 20130121@Dan: Change linked server DB06 to DBARC
		- 20131010@Kathy: Turn to use GlobalShowTime for display the Kick-off-Time [redmine:#6076]
		- 20141002@Sophia: Get the detail information of Tennis sport
		- 20140403@Sophia: Support BetRadar, correct Kickofftime
		- 20161007@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
		- 20170209@Kos: Add DISTINCT to prevent duplicate ticket detail [Redmine: #71007]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Sportsbook only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)

	DECLARE @tmpParlay TABLE(
		SportType		INT,
		LeagueId		INT,
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,
		HtHomeScore		INT,
		HtAwayScore		INT,
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		KickOffTime		DATETIME,
		EventDate		DATETIME,
		IsNeutral		BIT,
		BetStatus		VARCHAR(50),
		EventStatus		VARCHAR(15),
		IsRefund		BIT,
		IsCalRefund		BIT,
		GoalRecord		VARCHAR(50),
		MatchCode		VARCHAR(50),
		IsHTCal			BIT,
		Calculate		BIT,
		IsPending		BIT,
		BetType			SMALLINT,
		BetCheck		VARCHAR(50)
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
				ELSE
					CASE
						WHEN m.betstatus LIKE '%Abandoned 1H%' THEN 'Abandoned 1H'
						WHEN m.betstatus LIKE '%Abandoned 2H%' THEN 'Abandoned 2H'
						WHEN m.betstatus LIKE '%Refund FT%' THEN 'Refund FT'
						WHEN m.betstatus LIKE '%Refund HT%' THEN 'Refund HT'
						WHEN m.betstatus LIKE '%Refund%' THEN 'Refund'
						ELSE m.eventstatus
					END
			END AS eventstatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			m.goalrecord,
			m.matchcode,
			ISNULL(mr.IsHTCal, 0) AS isHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending,
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
			LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'

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
			LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) f
				ON f.Bettype = p.Bettype AND d.ResourceId LIKE f.ResourceID
		WHERE d.SettlementStatusID > 0
			AND ((p.Sporttype = 5
					AND CASE
							WHEN p.Bettype NOT IN (1324) THEN 2
							ELSE CASE
									WHEN p.Bettype IN (1324)
										AND LEFT(d.ResourceId,2) = LEFT(REPLACE (ISNULL(p.Betcheck,''), '8', ''), 2) THEN 4
									ELSE 0
								END
						END = LEN(d.ResourceId))
				OR (p.Sporttype = 1
					AND (d.ResourceId NOT IN ('00', '01', '08')
						OR (d.ResourceId = '08'
							AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
					AND d.ResourceId LIKE f.ResourceID))
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
				ELSE
					CASE
						WHEN m.betstatus LIKE '%Abandoned 1H%' THEN 'Abandoned 1H'
						WHEN m.betstatus LIKE '%Abandoned 2H%' THEN 'Abandoned 2H'
						WHEN m.betstatus LIKE '%Refund FT%' THEN 'Refund FT'
						WHEN m.betstatus LIKE '%Refund HT%' THEN 'Refund HT'
						WHEN m.betstatus LIKE '%Refund%' THEN 'Refund'
						ELSE m.eventstatus
					END 
			END AS eventstatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			m.goalrecord,
			m.matchcode,
			ISNULL(mr.IsHTCal, 0) AS isHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending,
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
			LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) f
				ON f.Bettype = p.Bettype AND d.ResourceId LIKE f.ResourceID
		WHERE d.SettlementStatusID > 0
			AND ((p.Sporttype = 5
					AND CASE WHEN p.Bettype NOT IN (1324) THEN 2
							ELSE CASE
									WHEN p.Bettype IN (1324)
										AND LEFT(d.ResourceId,2) = LEFT(REPLACE (ISNULL(p.Betcheck,''), '8', ''), 2) THEN 4 
									ELSE 0
								END
						END = LEN(d.ResourceId))
				OR (p.Sporttype = 1
					AND (d.ResourceId NOT IN ('00', '01', '08')
						OR (d.ResourceId = '08'
							AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
					AND d.ResourceId LIKE f.ResourceID))
	END

	-- Bettrans_bk range
	IF EXISTS (	SELECT 1
				FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
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
			CASE
				WHEN m.sporttype = 162 THEN m.kickofftime
				ELSE m.GlobalShowTime
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
				ELSE
					CASE
						WHEN m.betstatus LIKE '%Abandoned 1H%' THEN 'Abandoned 1H'
						WHEN m.betstatus LIKE '%Abandoned 2H%' THEN 'Abandoned 2H'
						WHEN m.betstatus LIKE '%Refund FT%' THEN 'Refund FT'
						WHEN m.betstatus LIKE '%Refund HT%' THEN 'Refund HT'
						WHEN m.betstatus LIKE '%Refund%' THEN 'Refund'
						ELSE m.eventstatus
					END
			END AS eventstatus,
			ISNULL(mr.refund, 0) IsRefund,
			ISNULL(mr.calrefund, 0) IsCalRefund,
			m.goalrecord,
			m.matchcode,
			ISNULL(mr.IsHTCal, 0) AS isHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending,
			bm.Bettype, 
			bm.Betcheck 
		FROM
			(
				SELECT
					bm.matchId,
					bm.Bettype,
					REPLACE(ISNULL(bm.Betcheck,''),'8','') AS BetCheck
				FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo ) bm
			INNER JOIN DBARC.bodb_Archive.dbo.match_BK AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN DBARC.bodb_Archive.dbo.ResultDetail_BK AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'

		INSERT INTO @tmpResultDetail
		SELECT
			d.MatchId,
			d.ResourceId,
			d.HomeValue,
			d.AwayValue,
			d.ResultStatusID,
			d.SettlementStatusID,
			d.OtherInfo
		FROM DBARC.bodb_archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
			INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
			LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) f
				ON	f.Bettype = p.Bettype AND d.ResourceId LIKE f.ResourceID
		WHERE d.SettlementStatusID > 0
			AND ((p.Sporttype = 5
					AND CASE
							WHEN p.Bettype NOT IN (1324) THEN 2
							ELSE CASE
									WHEN p.Bettype IN (1324)
										AND LEFT(d.ResourceId,2) = LEFT(REPLACE (ISNULL(p.Betcheck,''),'8',''),2) THEN 4
									ELSE 0
								END
						END = LEN(d.ResourceId))
				OR (p.Sporttype = 1
					AND (d.ResourceId NOT IN ('00', '01', '08')
						OR (d.ResourceId = '08'
							AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
					AND d.ResourceId LIKE f.ResourceID))
	END

	SELECT DISTINCT * FROM @tmpParlay
	ORDER BY LeagueId,
		BetType,
		EventDate,
		MatchCode

	-----> Order [LeagueID, Bettype] to group choices in Set x game y together in the same LeagueId.

	SELECT DISTINCT * FROM @tmpResultDetail
	ORDER BY MatchId,
		ResourceId
END



GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultParlay] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultParlay] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultParlay] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultParlay] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelMatchResultParlay] TO [vnteam]