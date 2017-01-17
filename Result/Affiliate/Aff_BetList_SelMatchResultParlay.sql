USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Aff_BetList_SelMatchResultParlay]    Script Date: 10/17/2014 8:36:19 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Aff_BetList_SelMatchResultParlay]
	@RefNo	BIGINT
AS

/*
	Created: 20141017@Bobby
	Task: Get parlay ticket result
	DB: DBEXT.bodb02
	Orgiginal: DBEXT/bodb02.dbo.Age_BetList_SelMatchResult

	Revisions:
		- 20141017@Bobby: Initial SP & Get the detail information of Tennis sport
		- 20150415@Bobby: Support for new 60 bettypes betradar
		- 20160425@Bobby: #56136 - Support Combo Parlay
		- 20161007@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161014@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
*/

BEGIN
	SET NOCOUNT ON;

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
		BetCheck		VARCHAR(50),
		TransDesc		NVARCHAR(200)
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
		;WITH BettransMix AS (
			SELECT
				b.matchId,
				b.bettype,
				REPLACE (ISNULL(b.betcheck,''),'8','') AS Betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM dbo.bettransm AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE b.refno = @RefNo
		)

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
			ISNULL(m.globalshowtime, m.kickofftime), -- kickofftime
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
			END AS EventStatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			m.goalrecord,
			m.matchcode,
			ISNULL(mr.IsHTCal, 0) AS isHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending,
			bm.Bettype,
			bm.Betcheck,
			bm.transdesc
		FROM BettransMix AS bm
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.matchID = M.MatchID AND d.ResourceId = '00'

		-- select from result detail
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
			INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
			LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) f
				ON f.Bettype = p.Bettype AND d.ResourceId LIKE f.ResourceID
		WHERE d.SettlementStatusID > 0
			AND ((p.Sporttype = 5
					AND CASE WHEN p.Bettype NOT IN (1324) THEN 2 ELSE 
							CASE
								WHEN p.Bettype IN (1324)
									AND LEFT(d.ResourceId, 2) = LEFT(REPLACE (ISNULL(p.Betcheck,''), '8', ''),2) THEN 4 
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
		WITH BettransMix AS (
			SELECT
				b.matchId,
				b.bettype,
				REPLACE (ISNULL(b.betcheck,''),'8','') AS Betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM dbo.bettransm14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE b.refno = @RefNo
		)

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
			ISNULL(m.globalshowtime, m.kickofftime), -- kickofftime
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
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			m.goalrecord,
			m.matchcode, 
			ISNULL(mr.IsHTCal, 0) AS isHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending,
			bm.Bettype,
			bm.Betcheck,
			bm.transdesc
		FROM BettransMix AS bm
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.MatchID = M.MatchID AND d.ResourceId = '00'

		-- select from result detail
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
					AND CASE WHEN p.Bettype NOT IN (1324) THEN 2 ELSE 
							CASE
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

	-- Bettrans_bk range
	IF EXISTS (	SELECT 1
				FROM DBARC.bodb_archive.dbo.BettransM AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE refno = @RefNo)
	BEGIN
		WITH BettransMix AS (
			SELECT b.matchId,
				b.Bettype,
				REPLACE (ISNULL(b.Betcheck,''),'8','') AS Betcheck,
				ISNULL(transdesc, '') AS transdesc
			FROM DBARC.bodb_Archive.dbo.bettransm AS b WITH (NOLOCK) 
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE b.refno = @RefNo 
		)

		INSERT INTO @tmpParlay
		SELECT
			m.sporttype,
			m.LeagueID,
			m.matchid,
			m.homeID,
			m.awayID,
			hthomescore,
			htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			ISNULL(m.globalshowtime, m.kickofftime), -- kickofftime
			m.eventdate,
			m.isNeutral,
			m.betstatus,
			CASE m.Sporttype
				WHEN 5 THEN
					CASE ISNULL(d.SettlementStatusID,0)
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
			ISNULL(mr.isHTCal, 0) AS isHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(mr.IsPending, 0) AS IsPending,
			bm.Bettype, 
			bm.Betcheck,
			bm.transdesc
		FROM BettransMix AS bm
			INNER JOIN DBARC.bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN DBARC.bodb_archive.dbo.ResultDetail_BK AS d WITH (NOLOCK) ON d.matchID = M.MatchID AND d.ResourceId = '00'

		-- select from result detail
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
					AND CASE WHEN p.Bettype NOT IN (1324) THEN 2 ELSE 
							CASE
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
	
	SELECT * FROM @tmpParlay
	ORDER BY LeagueId,
		EventDate,
		MatchCode

	SELECT DISTINCT * FROM @tmpResultDetail
	ORDER BY MatchId, ResourceId
END

GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelMatchResultParlay] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Aff_BetList_SelMatchResultParlay] TO [bodbDownlineNet] AS [dbo]
GO
