USE [bodb02]
GO
 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_SelMatchResultParlay]
	@RefNo	BIGINT
AS

/*
	Created: Henry@20101210
	Task: Get Parlay ticket result
	DB: DBEXT.bodb02
	Original: Age_BetList_SelMatchResultParlay
	Revisions:
		- 20110907@Sophia: Add column IsHTCal, calculate for Pending result.
		- 20110927@Henry: add more columns
		- 20131017@Jim: Turn to use GlobalShowTime for display the Kick-off-Time
		- 20141021@Jim : support to show Sportting Solution data detail 
		- 20140407@Sophia: Support BetRadar
		- 20161007@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpParlay TABLE (
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

	DECLARE @tmpResultDetail TABLE (
		MatchId				INT,
		ResourceId			VARCHAR(20),
		HomeValue			VARCHAR(20),
		AwayValue			VARCHAR(20),
		ResultStatusID		TINYINT,
		SettlementStatusID	TINYINT,
		OtherInfo			VARCHAR(50)
	)

	IF EXISTS (SELECT 1 FROM dbo.bettransm WITH (NOLOCK) WHERE refno = @refno)
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
				WHEN m.sporttype NOT IN (162, 161) THEN m.GlobalShowTime
				ELSE m.kickofftime
			END kickofftime,
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
						WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT' 
						WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
						WHEN m.betstatus LIKE 'Refund%' THEN 'Refund' 
						ELSE m.eventstatus
					END
			END AS eventstatus,
			ISNULL(mr.refund,0) IsRefund,
			ISNULL(mr.calrefund,0) IsCalRefund,
			m.goalrecord,
			m.matchcode,
			ISNULL(mr.isHTCal,0) AS isHTCal,
			ISNULL(mr.calculate,0) AS calculate,
			ISNULL(mr.IsPending,0) AS IsPending,
			bm.Bettype, 
			bm.Betcheck 
		FROM
			(
				SELECT
					matchId,
					bettype,
					betcheck
				FROM dbo.bettransm WITH (NOLOCK)
				WHERE refno = @refno ) bm
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'

		INSERT INTO @tmpResultDetail
		SELECT
			d.MatchID,
			d.ResourceId,
			d.HomeValue,
			d.AwayValue,
			d.ResultStatusID,
			d.SettlementStatusID,
			d.OtherInfo
		FROM dbo.ResultDetail AS d WITH (NOLOCK)
			INNER JOIN @tmpParlay AS p ON d.MatchId = p.MatchId
			LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F
				ON F.Bettype = p.Bettype AND d.ResourceId LIKE F.ResourceID
		WHERE d.SettlementStatusID > 0
			AND ((p.Sporttype = 5
					AND CASE WHEN p.Bettype NOT IN (1324) THEN 2 ELSE 
							CASE WHEN p.Bettype IN (1324) AND LEFT(d.ResourceId,2) = LEFT(REPLACE (ISNULL(p.Betcheck,''),'8',''),2) THEN 4 
							ELSE 0 END END = LEN(d.ResourceId))
				OR (p.Sporttype = 1
					AND (d.ResourceId NOT IN ('00', '01', '08')
						OR (d.ResourceId = '08'
							AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
					AND d.ResourceId LIKE F.ResourceID))
	END

	IF EXISTS (SELECT 1 FROM dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			m.sporttype,
			m.leagueid,
			m.matchid,
			m.homeid,
			m.awayid,
			hthomescore,
			htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			CASE
				WHEN m.sporttype NOT IN (162,161) THEN m.GlobalShowTime
				ELSE m.kickofftime
			END kickofftime,
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
						WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT' 
						WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
						WHEN m.betstatus LIKE 'Refund%' THEN 'Refund' 
						ELSE m.eventstatus
					END
			END AS eventstatus, 
			ISNULL(mr.refund,0) IsRefund,
			ISNULL(mr.calrefund,0) IsCalRefund,
			m.goalrecord,
			m.matchcode, 
			ISNULL(mr.isHTCal,0) AS isHTCal,
			ISNULL(mr.calculate,0) AS calculate,
			ISNULL(mr.IsPending,0) AS IsPending,
			bm.Bettype, 
			bm.Betcheck 
		FROM
			(
				SELECT
					matchId,
					bettype,
					betcheck
				FROM dbo.bettransm14 WITH (NOLOCK)
				WHERE refno = @refno ) bm
			INNER JOIN dbo.match14 AS m WITH(NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH(NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'

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
			LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F
				ON F.Bettype = p.Bettype AND d.ResourceId LIKE F.ResourceID
		WHERE d.SettlementStatusID > 0
			AND ((p.Sporttype = 5
					AND CASE WHEN p.Bettype NOT IN (1324) THEN 2 ELSE 
						CASE WHEN p.Bettype IN (1324) AND LEFT(d.ResourceId,2) = LEFT(REPLACE (ISNULL(p.Betcheck,''),'8',''),2) THEN 4 
						ELSE 0 END END = LEN(d.ResourceId))
				OR (p.Sporttype = 1
					AND (d.ResourceId NOT IN ('00', '01', '08')
						OR (d.ResourceId = '08'
							AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
					AND d.ResourceId LIKE F.ResourceID))
	END

	IF EXISTS (SELECT 1 FROM DBARC.bodb_archive.dbo.BettransM  WITH (NOLOCK) WHERE refno = @refno)
	BEGIN
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
			CASE
				WHEN m.sporttype NOT IN (162,161) THEN m.GlobalShowTime
				ELSE m.kickofftime
			END kickofftime,
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
						WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT' 
						WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
						WHEN m.betstatus LIKE 'Refund%' THEN 'Refund' 
						ELSE m.eventstatus
					END 
			END AS eventstatus,
			ISNULL(mr.refund,0) IsRefund,
			ISNULL(mr.calrefund,0) IsCalRefund,
			m.goalrecord,
			m.matchcode,
			ISNULL(mr.isHTCal,0) AS isHTCal,
			ISNULL(mr.calculate,0) AS calculate,
			ISNULL(mr.IsPending,0) AS IsPending,
			bm.Bettype, 
			bm.Betcheck 
		FROM
			(
				SELECT
					matchId,
					Bettype,
					Betcheck
				FROM DBARC.bodb_archive.dbo.BettransM WITH (NOLOCK)
				WHERE refno = @refno ) AS bm
			INNER JOIN DBARC.bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN DBARC.bodb_archive.dbo.ResultDetail_BK AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'
		
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
			LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS F
				ON F.Bettype = p.Bettype AND d.ResourceId LIKE F.ResourceID
		WHERE d.SettlementStatusID > 0
			AND ((p.Sporttype = 5
					AND CASE WHEN p.Bettype NOT IN (1324) THEN 2 ELSE 
							CASE WHEN p.Bettype IN (1324) AND LEFT(d.ResourceId,2) = LEFT(REPLACE (ISNULL(p.Betcheck,''),'8',''),2) THEN 4 
							ELSE 0 END END = LEN(d.ResourceId))
				OR (p.Sporttype = 1
					AND (d.ResourceId NOT IN ('00', '01', '08') 
						OR (d.ResourceId = '08'
							AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
					AND d.ResourceId LIKE F.ResourceID))
	END

	--- GET DATA 
	SELECT * FROM @tmpParlay
	ORDER BY LeagueId,
		BetType,
		EventDate,
		MatchCode
	
	SELECT DISTINCT * FROM @tmpResultDetail
	ORDER BY MatchId,
		ResourceId
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelMatchResultParlay] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelMatchResultParlay] TO [vnteam]