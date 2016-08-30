ALTER PROCEDURE [dbo].[Age_BetList_SelMatchResult]
	@MatchID	INT,
	@Bettype	SMALLINT	= NULL,
	@BetId		BIGINT		= NULL,
	@RaceNo		VARCHAR(50)	= NULL
AS

/*
	Created:
	Task: Get Result
	DB: DBAGE.bodb02

	Revisions:
		- 20091104@Jamie: Show the results of FOdds HR 
		- 20091130@Terry: Show the SCR info of FOdds HR
		- 20091130@Jamie: Get the HR results history (archive)
		- 20100123@Henry: Grant execute to Accounting site
		- 20100730@Henry: Grant execute to bodbExtAccNet
		- 20110307@Lukas: get more sporttype (152,153) & change column name (horseid -> runnerid)
		- 20110721@Johnson: get more columns for HR
		- 20110825@Johnson: get info horses scratched
		- 20110831@Johnson: correct event status when refund ticket
		- 20110907@Sophia: Add column IsHTCal, calculate for Pending Status.
		- 20111003@Sophia: Add column IsPending Pending Status.
		- 20120119@Sophia: Add Showtime for Table - hand - Shoe of Live Casino
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20130226@Elodie: Show the results of Virtual HR
		- 20130826@Kathy: change Status column name
		- 20130925@Lukas: revert column alias eventstatus -> status for horse racing product
		- 20131010@Kathy: Turn to use GlobalShowTime for display the Kick-off-Time [redmine:#6076] (exclusive LiveCasino)
		- 20140930@Sophia: Get the detail information of Tennis sport
		- 20140403@Sophia: Support BetRadar
		- 201600829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
*/

BEGIN
	SET NOCOUNT ON

	IF @RaceNo IS NULL
	BEGIN
		DECLARE @ResourceId	VARCHAR(20),
			@Sporttype		TINYINT

		SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20),@BetId), '8', '' ), 2)
		
		IF EXISTS(SELECT 1 FROM dbo.match WITH(NOLOCK) WHERE matchid = @matchid)
		BEGIN
			SELECT
				m.sporttype,
				m.betstatus,
				hthomescore,
				htawayscore,
				CASE
					WHEN m.sporttype = 162 THEN DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, m.GlobalShowTime, CURRENT_TIMESTAMP)
				END AS playtime,
				m.LeagueID,
				m.matchid, 
				m.homeID,
				m.awayID,
				m.matchcode,
				CASE
					WHEN m.sporttype = 162 THEN m.kickofftime
					ELSE m.GlobalShowTime
				END AS kickofftime,
				m.eventdate,
				m.finalhomescore,
				m.finalawayscore,
				CASE m.Sporttype
					WHEN 5 THEN
						CASE ISNULL(D.SettlementStatusID, 0)
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
				ISNULL(mr.refund, 0) IsRefund,
				ISNULL(mr.calrefund, 0) IsCalRefund,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				m.showtime
			FROM dbo.match m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail D WITH (NOLOCK) ON D.matchID = M.MatchID AND D.ResourceId = '00'
			WHERE m.matchid = @matchid
			ORDER BY m.eventdate,
				m.matchcode

			SELECT @Sporttype = Sporttype
			FROM dbo.match m WITH (NOLOCK)
			WHERE m.matchid = @matchid

			SELECT
				D.MatchId,
				D.ResourceId,
				D.HomeValue,
				D.AwayValue,
				D.ResultStatusID,
				D.SettlementStatusID,
				D.OtherInfo
			FROM dbo.ResultDetail D WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F
					ON F.Bettype = @Bettype AND D.ResourceId LIKE F.ResourceID
			WHERE D.MatchId = @MatchId AND D.SettlementStatusID > 0
				AND ((@Sporttype = 5
							AND CASE WHEN @Bettype NOT IN (1324) THEN 2 ELSE 
									CASE WHEN @Bettype IN (1324) AND LEFT(D.ResourceId,2) = @ResourceId THEN 4 
										ELSE 0 END END = LEN(D.ResourceId))
						OR 
						(@Sporttype = 1
							AND (D.ResourceId NOT IN ('00', '01', '08')
								OR (D.ResourceId = '08'
									AND (D.HomeValue LIKE '%a%' OR D.HomeValue LIKE '%h%')))
							AND D.ResourceId LIKE F.ResourceID))
			ORDER BY ResourceId

			RETURN
		END
		IF EXISTS(SELECT 1 FROM dbo.match14 WITH(NOLOCK) WHERE matchid = @matchid)
		BEGIN
			SELECT
				m.sporttype, 
				m.betstatus, 
				hthomescore,
				htawayscore,
				CASE
					WHEN m.sporttype = 162 THEN DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, m.GlobalShowTime, CURRENT_TIMESTAMP)
				END playtime,
				m.LeagueID,
				m.matchid, 
				m.homeID,
				m.awayID,
				m.matchcode,
				CASE
					WHEN m.sporttype = 162 THEN m.kickofftime
					ELSE m.GlobalShowTime
				END kickofftime,
				m.eventdate,
				m.finalhomescore,
				m.finalawayscore,
				CASE m.Sporttype
					WHEN 5 THEN
						CASE ISNULL(D.SettlementStatusID, 0)
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
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal,0) AS IsHTCal,
				ISNULL(mr.calculate,0) AS calculate,
				ISNULL(mr.IsPending,0) AS IsPending	,
				m.showtime
			FROM dbo.match14 AS m WITH(NOLOCK)
				LEFT OUTER JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail14 D WITH (NOLOCK) ON D.matchID = M.MatchID AND D.ResourceId = '00'
			WHERE m.matchid = @matchid
			ORDER BY m.eventdate,
				m.matchcode

			SELECT @Sporttype = Sporttype
			FROM dbo.match14 m WITH (NOLOCK)
			WHERE m.matchid = @matchid
		
			SELECT
				D.MatchId,
				D.ResourceId,
				D.HomeValue,
				D.AwayValue,
				D.ResultStatusID,
				D.SettlementStatusID,
				D.OtherInfo
			FROM dbo.ResultDetail14 D WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F 
					ON	F.Bettype = @Bettype
						AND D.ResourceId LIKE F.ResourceID	
			WHERE D.MatchId = @MatchId
				AND D.SettlementStatusID > 0
				AND (	(@Sporttype = 5
								AND CASE WHEN @Bettype NOT IN (1324) THEN 2 ELSE 
								 	CASE WHEN @Bettype IN (1324) AND LEFT(D.ResourceId,2) = @ResourceId THEN 4 
										ELSE 0 END END = LEN(D.ResourceId))
						OR 
						(@Sporttype = 1
							AND (D.ResourceId NOT IN ('00', '01', '08')
								OR (D.ResourceId = '08'
									AND (D.HomeValue LIKE '%a%' OR D.HomeValue LIKE '%h%')))
							AND D.ResourceId LIKE F.ResourceID))
			ORDER BY ResourceId

			RETURN
		END
		ELSE
		BEGIN
			SELECT
				m.sporttype, 
				m.betstatus, 
				hthomescore,
				htawayscore,
				CASE
					WHEN m.sporttype = 162 THEN DATEDIFF(MINUTE, m.kickofftime ,CURRENT_TIMESTAMP) 
					ELSE DATEDIFF(MINUTE, m.GlobalShowTime ,CURRENT_TIMESTAMP) 
				END playtime,
				m.LeagueID,
				m.matchid, 
				m.homeID,
				m.awayID,
				m.matchcode,
				m.eventdate,
				CASE
					WHEN m.sporttype = 162 THEN m.kickofftime
					ELSE m.GlobalShowTime
				END kickofftime,
				m.finalhomescore,
				m.finalawayscore,
				CASE m.Sporttype
					WHEN 5 THEN
						CASE ISNULL(D.SettlementStatusID,0)	 
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
						ELSE m.eventstatus END
					END AS eventstatus,
				ISNULL(mr.refund,0) IsRefund,
				ISNULL(mr.calrefund,0) IsCalRefund,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				m.showtime 
			FROM DBARC.bodb_archive.dbo.Match_BK m WITH(NOLOCK)
				LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN DBARC.bodb_archive.dbo.ResultDetail_BK D WITH (NOLOCK) ON D.matchID = M.MatchID AND D.ResourceId = '00'
			WHERE m.matchid = @matchid
			ORDER BY m.eventdate,
				m.matchcode

			SELECT @Sporttype = Sporttype
			FROM DBARC.bodb_archive.dbo.match_bk m WITH (NOLOCK)
			WHERE m.matchid = @matchid
		
			SELECT
				D.MatchId,
				D.ResourceId,
				D.HomeValue,
				D.AwayValue,
				D.ResultStatusID,
				D.SettlementStatusID,
				D.OtherInfo
			FROM DBARC.bodb_archive.dbo.ResultDetail_BK D WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F
					ON	F.Bettype = @Bettype
						AND D.ResourceId LIKE F.ResourceID	
			WHERE D.MatchId = @MatchId
				AND D.SettlementStatusID > 0
				AND (	(@Sporttype = 5
							AND CASE WHEN @Bettype NOT IN (1324) THEN 2 ELSE 
									CASE WHEN @Bettype IN (1324) AND LEFT(D.ResourceId,2) = @ResourceId THEN 4 
										ELSE 0 END END = LEN(D.ResourceId))
						OR 
						(@Sporttype = 1
							AND (D.ResourceId NOT IN ('00', '01', '08')
								OR (D.ResourceId = '08'
									AND (D.HomeValue LIKE '%a%' OR D.HomeValue LIKE '%h%')))
							AND D.ResourceId LIKE F.ResourceID))
			ORDER BY ResourceId
		END
	END
	ELSE
	BEGIN
		DECLARE @leagueid	INT,
			@eventdate		DATETIME 

		IF EXISTS (SELECT 1 FROM outright WITH(NOLOCK) WHERE orid = @matchid)
		BEGIN
			SELECT @leagueid = leagueid,
				@eventdate = eventdate 
			FROM dbo.outright WITH (NOLOCK)
			WHERE orid = @matchid 

			SELECT
				matchcode AS horseNo, 
				CAST(o.groupmatch AS INT) AS racename,
				placing AS place, 
				l.sporttype, 
				teamid horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus status,
				o.IsFavor,
				o.IsSCR,
				o.FOddsStatus
			FROM Outright o WITH (NOLOCK)
				INNER JOIN league l WITH(NOLOCK) ON o.leagueid = l.leagueid
			WHERE o.leagueid = @leagueid 
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate 
				AND ( ISNULL(placing,0) <> 0 OR isScr = 1)
			ORDER BY placing
		END 
		ELSE IF EXISTS (SELECT 1 FROM Outright14 WITH (NOLOCK) WHERE orid = @matchid)
		BEGIN
			SELECT @leagueid = leagueid,
				@eventdate = eventdate 
			FROM Outright14 WITH (NOLOCK)
			WHERE orid = @matchid 

			SELECT
				matchcode AS horseNo, 
				CAST(o.groupmatch AS INT) AS racename,
				placing AS place, 
				l.sporttype, 
				teamid horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus status,
				o.IsFavor,
				o.IsSCR,
				o.FOddsStatus
			FROM Outright14 o WITH (NOLOCK)
				INNER JOIN league l WITH(NOLOCK) ON l.leagueid = o.leagueid
			WHERE o.leagueid = @leagueid 
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate 
				AND (ISNULL(placing,0) <> 0  OR isScr = 1)
			ORDER BY placing
		END 
		ELSE IF EXISTS( SELECT 1 FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK) WHERE orid = @matchid)
		BEGIN
			SELECT @leagueid = leagueid,
				@eventdate = eventdate 
			FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK)
			WHERE orid = @matchid 

			SELECT
				matchcode AS horseNo, 
				CAST(bk.groupmatch AS INT) AS racename,
				placing AS place, 
				l.sporttype, 
				teamid horseid,
				bk.odds,
				bk.placeodds,
				bk.leagueid AS meetingid,
				bk.oddsstatus status,
				bk.IsFavor,
				bk.IsSCR,
				bk.FOddsStatus
			FROM DBARC.bodb_Archive.dbo.Outright_bk bk WITH (NOLOCK)
				INNER JOIN league l WITH(NOLOCK) ON l.leagueid = bk.leagueid
			WHERE bk.leagueid = @leagueid 
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate 
				AND (ISNULL(placing,0)<> 0  OR isScr = 1)
			ORDER BY placing
		END
		ELSE IF EXISTS(SELECT 1 FROM VSOutright WITH(NOLOCK) WHERE orid = @RaceNo)
		BEGIN
			-- Virtual HR 
			SELECT
				RacerNum AS horseNo, 
				r.EventTime AS racename,
				placing AS place, 
				r.SportType,
				o.RacerID horseid,
				o.WinOdds odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus eventstatus,
				o.IsFavor,
				'' IsSCR,
				'' FOddsStatus
			FROM VSOutright o WITH (NOLOCK)
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(placing, 0) <> 0)
			ORDER BY placing
		END
		ELSE IF EXISTS(SELECT 1 FROM VSOutright14 WITH(NOLOCK) WHERE orid = @RaceNo)
		BEGIN
			-- Virtual HR 
			SELECT 
				RacerNum AS horseNo, 
				r.EventTime AS racename,
				placing AS place, 
				r.SportType,
				o.RacerID horseid,
				o.WinOdds odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus eventstatus,
				o.IsFavor,
				'' IsSCR,
				'' FOddsStatus
			FROM VSOutright14 o WITH (NOLOCK)
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(placing,0) <> 0)
			ORDER BY placing
		END
		ELSE
		BEGIN
			-- Virtual HR 
			SELECT
				RacerNum AS horseNo, 
				r.EventTime AS racename,
				placing AS place, 
				r.SportType,
				o.RacerID horseid,
				o.WinOdds odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus eventstatus,
				o.IsFavor,
				'' IsSCR,
				'' FOddsStatus
			FROM DBARC.bodb_Archive.dbo.VSOutright_bk o WITH (NOLOCK)
				 INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(placing,0) <> 0)
			ORDER BY placing
		END
	END
END



GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResult] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResult] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResult] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResult] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelMatchResult] TO [vnteam]