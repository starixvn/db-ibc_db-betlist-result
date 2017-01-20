ALTER PROCEDURE [dbo].[Acc_BetList_SelMatchResult]
	@MatchId	INT,
	@BetType	SMALLINT	= NULL,
	@BetId		BIGINT		= NULL,
	@RaceNo		VARCHAR(50)	= NULL
AS

/*
	Created:
	Task: Get ticket result
	DB: DBAGE.bodb02
	Original: Age_BetList_SelMatchResult

	Revisions:
		- 20091104@Jamie: Show the results of FOdds HR
		- 20091130@Terry: Show the SCR info of FOdds HR
		- 20091130@Jamie: Get the HR results history (archive)
		- 20100123@Henry: Grant execute to Accounting site
		- 20100730@Henry: Grant execute to bodbExtAccNet
		- 20110307@Lukas: Get more sporttype (152,153) & change column name (horseid -> runnerid)
		- 20110907@Sophia: Add column IsHTCal, calculate for Pending Status. Edit eventstatus
		- 20111003@Sophia: Add column IsPending Pending Status.
		- 20120130@Sopghia: Add Showtime for Table - hand - Shoe of Live Casino
		- 20120921@Elodie: Get kickofftime field
		- 20130121@Dan: Change linked server DB06 to DBARC
		- 20130226@Elodie: Show the results of Virtual HR
		- 20140930@Sophia: Get the detail information of Tennis sport
		- 20140414@Sophia: Support Bet Radar
		- 20160504@Kos: Support Fast Market [#Redmine: 56589]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161031@Kos: Support live score [#Redmine: 66447]
		- 20170116@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
		- 20170120@Kos: Get result detail of bet type 221 in case of 225 [#Redmine: 56589]
*/

BEGIN
	SET NOCOUNT ON

	IF @RaceNo IS NULL
	BEGIN
		DECLARE @ResourceId	VARCHAR(20),
			@Sporttype		TINYINT

		SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', '' ), 2)

		-- Get result detail of bet type 221 in case of 225
		IF @BetType = 225
			SET @BetType = 221

		IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @matchid)
		BEGIN
			SELECT
				m.sporttype,
				m.betstatus,
				m.hthomescore,
				m.htawayscore,
				DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) AS playtime,
				m.leagueid,
				m.matchid,
				m.homeid,
				m.awayid,
				m.matchcode,
				m.kickofftime,
				m.eventdate,
				m.finalhomescore,
				m.finalawayscore,
				m.livehomescore,
				m.liveawayscore,
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
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				m.showtime
			FROM dbo.match AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'
			WHERE m.matchid = @matchid
			ORDER BY m.eventdate,
				m.matchcode

			SELECT @Sporttype = Sporttype
			FROM dbo.match WITH (NOLOCK)
			WHERE matchid = @matchid

			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F
					ON F.Bettype = @Bettype AND d.ResourceId LIKE F.ResourceID
			WHERE d.MatchId = @MatchId
				AND (d.SettlementStatusID > 0
					OR d.ResourceID LIKE '221%'
					OR d.ResourceID LIKE '222%'
					OR d.ResourceID LIKE '223%'
					OR d.ResourceID LIKE '224%'
					OR d.ResourceID LIKE '225%')
				AND (	(@Sporttype = 5
							AND CASE
									WHEN @Bettype NOT IN (1324) THEN 2
									ELSE
										CASE
											WHEN @Bettype IN (1324) AND LEFT(d.ResourceId,2) = @ResourceId THEN 4
											ELSE 0
										END
								END = LEN(d.ResourceId))
						OR (@Sporttype = 1
							AND (d.ResourceId NOT IN ('00', '01', '08')
								OR (d.ResourceId = '08'
									AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
							AND d.ResourceId LIKE F.ResourceID))
			ORDER BY ResourceId

			RETURN
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.match14 WITH (NOLOCK) WHERE matchid = @matchid)
		BEGIN
			SELECT
				m.sporttype,
				m.betstatus,
				m.hthomescore,
				m.htawayscore,
				DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) AS playtime,
				m.leagueid,
				m.matchid,
				m.homeid,
				m.awayid,
				m.matchcode,
				m.kickofftime,
				m.eventdate,
				m.finalhomescore,
				m.finalawayscore,
				m.livehomescore,
				m.liveawayscore,
				CASE m.sporttype
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
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				m.showtime
			FROM dbo.match14 AS m WITH(NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'
			WHERE m.matchid = @matchid
			ORDER BY m.eventdate,
				m.matchcode

			SELECT @Sporttype = sporttype
			FROM dbo.match14 WITH (NOLOCK)
			WHERE matchid = @matchid

			SELECT
				d.MatchID,
				d.ResourceID,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail14 AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS F
					ON F.Bettype = @Bettype AND d.ResourceId LIKE F.ResourceID
			WHERE d.MatchId = @MatchId
				AND (d.SettlementStatusID > 0
					OR d.ResourceID LIKE '221%'
					OR d.ResourceID LIKE '222%'
					OR d.ResourceID LIKE '223%'
					OR d.ResourceID LIKE '224%'
					OR d.ResourceID LIKE '225%')
				AND (	(@Sporttype = 5
							AND CASE
									WHEN @Bettype NOT IN (1324) THEN 2
									ELSE
										CASE
											WHEN @Bettype IN (1324) AND LEFT(d.ResourceId,2) = @ResourceId THEN 4 
											ELSE 0
										END
								END = LEN(d.ResourceId))
						OR (@Sporttype = 1
							AND (d.ResourceId NOT IN ('00', '01', '08')
								OR (d.ResourceId = '08'
									AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
							AND d.ResourceId LIKE F.ResourceID))
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
				DATEDIFF(MINUTE, kickofftime, CURRENT_TIMESTAMP) playtime,
				m.LeagueID,
				m.matchid,
				m.homeID,
				m.awayID,
				m.matchcode,
				m.kickofftime,
				m.eventdate,
				m.finalhomescore,
				m.finalawayscore,
				m.livehomescore,
				m.liveawayscore,
				CASE m.sporttype
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
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				m.showtime
			FROM DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN DBARC.bodb_Archive.dbo.ResultDetail_bk AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId
			ORDER BY m.eventdate,
				m.matchcode

			SELECT @Sporttype = Sporttype
			FROM DBARC.bodb_archive.dbo.match_BK WITH (NOLOCK)
			WHERE matchid = @matchid

			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM DBARC.bodb_archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS F
					ON F.Bettype = @Bettype AND d.ResourceId LIKE F.ResourceID
			WHERE d.MatchId = @MatchId
				AND (d.SettlementStatusID > 0
					OR d.ResourceID LIKE '221%'
					OR d.ResourceID LIKE '222%'
					OR d.ResourceID LIKE '223%'
					OR d.ResourceID LIKE '224%'
					OR d.ResourceID LIKE '225%')
				AND (	(@Sporttype = 5
							AND CASE
									WHEN @Bettype NOT IN (1324) THEN 2
									ELSE
										CASE
											WHEN @Bettype IN (1324) AND LEFT(d.ResourceId,2) = @ResourceId THEN 4 
											ELSE 0
										END
								END = LEN(d.ResourceId))
						OR (@Sporttype = 1
							AND (d.ResourceId NOT IN ('00', '01', '08')
								OR (d.ResourceId = '08'
									AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
							AND d.ResourceId LIKE F.ResourceID))
			ORDER BY ResourceId
		END
	END
	ELSE
	BEGIN
		DECLARE @leagueid	INT,
			@eventdate		DATETIME

		IF EXISTS (SELECT 1 FROM dbo.outright WITH (NOLOCK) WHERE orid = @matchid)
		BEGIN
			SELECT @leagueid = leagueid,
				@eventdate = eventdate
			FROM dbo.outright WITH (NOLOCK)
			WHERE orid = @matchid

			SELECT
				o.matchcode,
				o.Placing,
				l.sporttype,
				o.teamid AS Runner,
				o.leagueid,
				'' EventTime,
				'' HorseNo,
				'' WinOdds,
				'' PlaceOdds,
				'' IsFavor
			FROM dbo.outright AS o WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE o.leagueid = @leagueid
				AND o.groupmatch = @RaceNo
				AND o.eventdate = @eventdate
				AND ISNULL(o.Placing, 0) <> 0
			ORDER BY o.Placing
		
			SELECT
				matchcode,
				teamid,
				CONVERT(VARCHAR, SCRTime, 108) AS SCRTime,
				risk AS Deduction
			FROM dbo.outright WITH (NOLOCK)
			WHERE leagueid = @leagueid
				AND groupmatch = @raceNo
				AND eventdate = @eventdate
				AND IsSCR = 1
				AND FOddsStatus = 'completed'
			ORDER BY CAST(matchcode AS TINYINT)
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.outright14 WITH (NOLOCK) WHERE orid = @matchid)
		BEGIN
			SELECT @leagueid = leagueid,
				@eventdate = eventdate
			FROM dbo.outright14 WITH (NOLOCK)
			WHERE orid = @matchid

			SELECT
				o.matchcode,
				o.Placing,
				l.sporttype,
				o.teamid AS runner,
				o.leagueid,
				'' EventTime,
				'' HorseNo,
				'' WinOdds,
				'' PlaceOdds,
				'' IsFavor
			FROM dbo.outright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE o.leagueid = @leagueid
				AND o.groupmatch = @RaceNo
				AND o.eventdate = @eventdate
				AND ISNULL(o.Placing, 0) <> 0
			ORDER BY o.Placing

			SELECT
				matchcode,
				teamid,
				CONVERT(VARCHAR,SCRTime,108) SCRTime,
				risk Deduction
			FROM dbo.outright14 WITH (NOLOCK)
			WHERE leagueid = @leagueid
				AND groupmatch = @raceNo
				AND eventdate = @eventdate
				AND IsSCR = 1
				AND FOddsStatus = 'completed'
			ORDER BY CAST (matchcode AS TINYINT) 
		END
		ELSE IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK) WHERE orid = @matchid)
		BEGIN
			SELECT @leagueid = leagueid,
				@eventdate = eventdate 
			FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK)
			WHERE orid = @matchid 

			SELECT
				matchcode,
				placing,
				l.sporttype,
				teamid AS runner,
				bk.leagueid,
				'' EventTime,
				'' HorseNo,
				'' WinOdds,
				'' PlaceOdds,
				'' IsFavor
			FROM DBARC.bodb_Archive.dbo.Outright_bk bk WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = bk.leagueid
			WHERE bk.leagueid = @leagueid
				AND groupmatch = @RaceNo
				AND eventdate = @eventdate
				AND ISNULL(placing, 0) <> 0
			ORDER BY placing

			SELECT
				matchcode,
				teamid,
				CONVERT(VARCHAR,SCRTime,108) SCRTime,
				risk AS Deduction
			FROM DBARC.bodb_archive.dbo.Outright_bk WITH (NOLOCK)
			WHERE leagueid = @leagueid
				AND groupmatch = @raceNo
				AND eventdate = @eventdate
				AND IsSCR = 1
				AND FOddsStatus = 'completed'
			ORDER BY CAST (matchcode AS TINYINT)
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE orid = @RaceNo)
		BEGIN
			SELECT
				'' matchcode,
				o.Placing,
				r.sporttype,
				o.RacerID runner,
				r.leagueid,
				r.EventTime,
				o.RacerNum HorseNo,
				o.WinOdds,
				o.PlaceOdds,
				o.IsFavor
			FROM dbo.VSOutright AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND ISNULL(o.Placing, 0) <> 0
			ORDER BY o.Placing

			SELECT
				'' matchcode,
				0,
				'' SCRTime,
				0 Deduction
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.VSOutright14 WITH (NOLOCK) WHERE orid = @RaceNo)
		BEGIN
			SELECT
				'' matchcode,
				o.Placing,
				r.sporttype,
				o.RacerID runner,
				r.leagueid,
				r.EventTime,
				o.RacerNum HorseNo,
				o.WinOdds,
				o.PlaceOdds,
				o.IsFavor
			FROM dbo.VSOutright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchId AND ISNULL(o.Placing, 0) <> 0
			ORDER BY o.Placing

			SELECT
				'' matchcode,
				0,
				'' SCRTime,
				0 Deduction
		END
		ELSE IF EXISTS (SELECT 1 FROM DBARC.bodb_archive.dbo.VSOutright_bk WITH (NOLOCK) WHERE orid = @RaceNo)
		BEGIN
			SELECT
				'' matchcode,
				placing,
				r.sporttype,
				RacerID runner,
				r.leagueid,
				r.EventTime,
				RacerNum HorseNo,
				o.WinOdds,
				o.PlaceOdds,
				o.IsFavor
			FROM DBARC.bodb_archive.dbo.VSOutright_bk AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchId AND ISNULL(placing, 0) <> 0
			ORDER BY placing

			SELECT
				'' matchcode,
				0,
				'' SCRTime,
				0 Deduction
		END 
	END
END




GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelMatchResult] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelMatchResult] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetList_SelMatchResult] TO [vnteam]