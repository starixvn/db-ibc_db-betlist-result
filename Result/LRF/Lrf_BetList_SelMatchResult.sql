/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

USE [bodb02]
GO
 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelMatchResult]
	@MatchId	INT,
	@RaceNo		VARCHAR(50)	= NULL,
	@BetType	SMALLINT	= NULL,
	@BetId		BIGINT		= NULL
AS

/*
	Created: Henry@20101210
	Task: Get Result of match
	DB: DBEXT.bodb02

	Revisions:
		- 20110308@Henry: Get more sporttype (152, 153)
		- 20110907@Sophia: Add column IsHTCal, calculate for pending result
		- 20110926@Henry: Add column kickofftime, IsPending, add more columns for HR
		- 20120817@Henry: Add Showtime for Table - hand - Shoe of Live Casino
		- 20120911@Henry: Add homeid2 for Roulettle
		- 20130403@Jim: Support base currency USD
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130722@Jim: Support Virtual Horse Racing
		- 20131017@Jim: Turn to use GlobalShowTime for display the Kick-off-Time
		- 20131129@Jim: Support 182 – Virtual Greyhounds, 184 – Virtual Motor Racing
		- 20140428@Hannah: Support 183 - Virtual Speedway, 185 - Virtual Cycling
		- 20141021@Jim: Support to show Sportting Solution data detail 
		- 20140403@Sophia: Support BetRadar
		- 20160504@Kos: Support Fast Market [#Redmine: 56589]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161031@Kos: Support live score [#Redmine: 66447]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
		- 20170120@Kos: Get result detail of bet type 221 in case of 225 [#Redmine: 56589]
		- 20170418@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170613@Kos: Get data from DBARC.bodb_Archive.dbo.match_remark for bk range instead [#Redmine: 78212]
					- Remove params @LicenseeId and @UserId
		- 20170919@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
		- 20180103@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180320@Kos: Support Fast Market 2 [#Redmine: 90879]
		- 20180406@Kos: Support Betradar Virtual Basketball [Redmine: #90881]

		*******************
		sample test case:
			exec Lrf_BetList_SelMatchResult @MatchID=10514601, @RaceNo=default, @BetType = 1324,
				@Betid='801', @LicenseeID=1, @UserID=10
*/

BEGIN
	SET NOCOUNT ON

	IF @RaceNo IS NULL
	BEGIN
		DECLARE @ResourceId	VARCHAR(20),
			@SportType		SMALLINT

		-- Get result detail of bet type 221 in case of 225
		IF @BetType = 225
			SET @BetType = 221

		IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId)
		BEGIN
			SELECT
				m.sporttype,
				m.betstatus,
				m.hthomescore,
				m.htawayscore,
				CASE
					WHEN m.sporttype <> 161 THEN DATEDIFF(MINUTE, m.GlobalShowTime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP)
				END AS PlayTime,
				m.leagueid,
				m.matchid,
				m.homeid,
				m.awayid,
				m.matchcode,
				CASE
					WHEN m.sporttype <> 161 THEN m.GlobalShowTime
					ELSE m.kickofftime
				END AS KickOffTime,
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
				END AS EventStatus,
				ISNULL(mr.refund, 0) AS IsRefund,
				ISNULL(mr.calrefund, 0) AS IsCalRefund,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				ISNULL(m.showtime, '') AS showtime,
				m.homeid2
			FROM dbo.match AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.MatchID = m.matchid AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId
			ORDER BY m.eventdate,
				m.matchcode

			-- Get sport type
			SELECT @SportType = sporttype
			FROM dbo.match WITH (NOLOCK)
			WHERE matchid = @MatchId

			IF @SportType = 5
				SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
			ELSE
				SELECT @ResourceId = REPLACE(CONVERT(VARCHAR(20), @BetId), '8', '')

			-- Get result detail
			IF @SportType <> 193
			BEGIN
				SELECT
					d.MatchId,
					d.ResourceId,
					d.HomeValue,
					d.AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM dbo.ResultDetail AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) f
						ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
				WHERE d.MatchId = @MatchId
					AND ((@SportType = 5						-- Tennis
							AND d.SettlementStatusID > 0
							AND CASE WHEN @BetType NOT IN (1324) THEN 2 ELSE
									CASE WHEN @BetType IN (1324) AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
										ELSE 0 END END = LEN(d.ResourceId))
						OR (@SportType = 1						-- Soccer
							AND (d.SettlementStatusID > 0
								OR d.ResourceID LIKE '221%'
								OR d.ResourceID LIKE '222%'
								OR d.ResourceID LIKE '223%'
								OR d.ResourceID LIKE '224%'
								OR d.ResourceID LIKE '225%'
								OR d.ResourceID LIKE '226%'
								OR d.ResourceID LIKE '227%')
							AND (d.ResourceId NOT IN ('00', '01', '08')
								OR (d.ResourceId = '08'
									AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
							AND d.ResourceId LIKE f.ResourceID)
						OR (@SportType = 2						-- Basketball
							AND (LEN(d.ResourceId) = 2
								OR (d.SettlementStatusID > 0
									AND d.ResourceId LIKE f.ResourceID
									AND (@BetType NOT IN (606, 607, 613, 617)
										OR d.ResourceId LIKE '%' + @ResourceId)))))
				ORDER BY d.ResourceID
			END
			ELSE
			BEGIN
				SELECT
					d.MatchID,
					d.ResourceId,
					d.Custom1 AS HomeValue,
					d.Custom2 AS AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM dbo.ResultDetail3rd AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
						ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
				WHERE d.MatchID = @MatchId
					AND (@SportType = 193
						AND d.SettlementStatusID > 0
						AND (d.ResourceID IN ('00', '01')
							OR (d.ResourceID LIKE f.ResourceID
								AND (@BetType <> 2809
									OR d.ResourceID LIKE '%' + @ResourceId))))
				ORDER BY d.ResourceId
			END

			RETURN
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.match14 WITH (NOLOCK) WHERE matchid = @MatchId)
		BEGIN
			SELECT
				m.sporttype,
				m.betstatus,
				m.hthomescore,
				m.htawayscore,
				CASE
					WHEN m.sporttype <> 161 THEN DATEDIFF(MINUTE, m.globalshowtime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP)
				END AS playtime,
				m.leagueid,
				m.matchid,
				m.homeid,
				m.awayid,
				m.matchcode,
				CASE
					WHEN m.sporttype <> 161 THEN m.GlobalShowTime
					ELSE m.kickofftime
				END AS KickOffTime,
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
				END AS EventStatus,
				ISNULL(mr.refund, 0) AS IsRefund,
				ISNULL(mr.calrefund, 0) AS IsCalRefund,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				ISNULL(m.showtime, '') AS showtime,
				m.homeid2
			FROM dbo.match14 AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId
			ORDER BY m.eventdate,
				m.matchcode

			-- Get sport type
			SELECT @SportType = sporttype
			FROM dbo.match14 WITH (NOLOCK)
			WHERE matchid = @MatchId

			IF @SportType = 5
				SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
			ELSE
				SELECT @ResourceId = REPLACE(CONVERT(VARCHAR(20), @BetId), '8', '')

			-- Get result detail
			IF @SportType <> 193
			BEGIN
				SELECT
					d.MatchId,
					d.ResourceId,
					d.HomeValue,
					d.AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM dbo.ResultDetail14 AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) f
						ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
				WHERE d.MatchId = @MatchId
					AND ((@SportType = 5						-- Tennis
							AND d.SettlementStatusID > 0
							AND CASE WHEN @BetType NOT IN (1324) THEN 2 ELSE
									CASE WHEN @BetType IN (1324) AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
										ELSE 0 END END = LEN(d.ResourceId))
						OR (@SportType = 1						-- Soccer
							AND (d.SettlementStatusID > 0
								OR d.ResourceID LIKE '221%'
								OR d.ResourceID LIKE '222%'
								OR d.ResourceID LIKE '223%'
								OR d.ResourceID LIKE '224%'
								OR d.ResourceID LIKE '225%'
								OR d.ResourceID LIKE '226%'
								OR d.ResourceID LIKE '227%')
							AND (d.ResourceId NOT IN ('00', '01', '08')
								OR (d.ResourceId = '08'
									AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
							AND d.ResourceId LIKE f.ResourceID)
						OR (@SportType = 2						-- Basketball
							AND (LEN(d.ResourceId) = 2
								OR (d.SettlementStatusID > 0
									AND d.ResourceId LIKE f.ResourceID
									AND (@BetType NOT IN (606, 607, 613, 617)
										OR d.ResourceId LIKE '%' + @ResourceId)))))
				ORDER BY d.ResourceID
			END
			ELSE
			BEGIN
				SELECT
					d.MatchID,
					d.ResourceId,
					d.Custom1 AS HomeValue,
					d.Custom2 AS AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM dbo.ResultDetail3rd14 AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
						ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
				WHERE d.MatchID = @MatchId
					AND (@SportType = 193
						AND d.SettlementStatusID > 0
						AND (d.ResourceID IN ('00', '01')
							OR (d.ResourceID LIKE f.ResourceID
								AND (@BetType <> 2809
									OR d.ResourceID LIKE '%' + @ResourceId))))
				ORDER BY d.ResourceId
			END

			RETURN
		END
		ELSE
		BEGIN
			SELECT
				m.sporttype,
				m.betstatus,
				m.hthomescore,
				m.htawayscore,
				CASE
					WHEN m.sporttype <> 161 THEN DATEDIFF(MINUTE, m.GlobalShowTime, CURRENT_TIMESTAMP)
					ELSE DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP)
				END AS PlayTime,
				m.LeagueID,
				m.matchid,
				m.homeID,
				m.awayID,
				m.matchcode,
				CASE
					WHEN m.sporttype <> 161 THEN m.GlobalShowTime
					ELSE m.kickofftime
				END AS KickOffTime,
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
				END AS EventStatus,
				ISNULL(mr.refund, 0) AS IsRefund,
				ISNULL(mr.calrefund, 0) AS IsCalRefund,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(mr.IsPending, 0) AS IsPending,
				ISNULL(m.showtime, '') AS showtime,
				m.homeid2
			FROM DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
				LEFT OUTER JOIN DBARC.bodb_Archive.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN DBARC.bodb_Archive.dbo.ResultDetail_BK AS d WITH (NOLOCK) ON d.matchID = M.MatchID AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId
			ORDER BY m.eventdate,
				m.matchcode

			-- Get sport type
			SELECT @SportType = Sporttype
			FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK)
			WHERE matchid = @MatchId

			IF @SportType = 5
				SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
			ELSE
				SELECT @ResourceId = REPLACE(CONVERT(VARCHAR(20), @BetId), '8', '')

			-- Get result detail
			IF @SportType <> 193
			BEGIN
				SELECT
					d.MatchId,
					d.ResourceId,
					d.HomeValue,
					d.AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM DBARC.bodb_archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F
						ON F.Bettype = @BetType AND d.ResourceId LIKE F.ResourceID
				WHERE d.MatchId = @MatchId
					AND ((@SportType = 5						-- Tennis
							AND d.SettlementStatusID > 0
							AND CASE WHEN @BetType NOT IN (1324) THEN 2 ELSE
									CASE WHEN @BetType IN (1324) AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
										ELSE 0 END END = LEN(d.ResourceId))
						OR (@SportType = 1						-- Soccer
							AND (d.SettlementStatusID > 0
								OR d.ResourceID LIKE '221%'
								OR d.ResourceID LIKE '222%'
								OR d.ResourceID LIKE '223%'
								OR d.ResourceID LIKE '224%'
								OR d.ResourceID LIKE '225%'
								OR d.ResourceID LIKE '226%'
								OR d.ResourceID LIKE '227%')
							AND (d.ResourceId NOT IN ('00', '01', '08')
								OR (d.ResourceId = '08'
									AND (d.HomeValue LIKE '%a%' OR d.HomeValue LIKE '%h%')))
							AND d.ResourceId LIKE f.ResourceID)
						OR (@SportType = 2						-- Basketball
							AND (LEN(d.ResourceId) = 2
								OR (d.SettlementStatusID > 0
									AND d.ResourceId LIKE f.ResourceID
									AND (@BetType NOT IN (606, 607, 613, 617)
										OR d.ResourceId LIKE '%' + @ResourceId)))))
				ORDER BY d.ResourceID
			END
			ELSE
			BEGIN
				SELECT
					d.MatchID,
					d.ResourceId,
					d.Custom1 AS HomeValue,
					d.Custom2 AS AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM DBARC.bodb_Archive.dbo.ResultDetail3rd_BK AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
						ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
				WHERE d.MatchID = @MatchId
					AND (@SportType = 193
						AND d.SettlementStatusID > 0
						AND (d.ResourceID IN ('00', '01')
							OR (d.ResourceID LIKE f.ResourceID
								AND (@BetType <> 2809
									OR d.ResourceID LIKE '%' + @ResourceId))))
				ORDER BY d.ResourceId
			END
		END
	END
	ELSE
	BEGIN
		CREATE TABLE #tmpresult (
			HorseNo		VARCHAR(50),
			KickOffTime	DATETIME,
			RaceName	VARCHAR(50),
			Place		TINYINT,
			SportType	INT,
			HorseId		INT,
			Odds		SMALLMONEY,
			PlaceOdds	SMALLMONEY,
			MeetingId	INT,
			OddsStatus	VARCHAR(10),
			IsFavor		VARCHAR(10),
			IsSCR		BIT,
			FOddsStatus	VARCHAR(10))

		DECLARE @LeagueId	INT,
			@EventDate		DATETIME

		IF EXISTS (SELECT 1 FROM dbo.outright WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @LeagueId = leagueid,
				@EventDate = eventdate
			FROM dbo.outright WITH (NOLOCK)
			WHERE orid = @MatchId

			INSERT INTO #tmpresult
			SELECT
				o.matchcode AS horseNo,
				NULL,
				CAST(o.groupmatch AS INT) AS racename,
				CASE WHEN o.placing = 0 THEN 5 ELSE ISNULL(o.Placing, 5) END place,
				l.sporttype,
				o.teamid AS horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus AS status,
				CONVERT(VARCHAR(10), o.IsFavor),
				o.IsSCR,
				o.FOddsStatus
			FROM dbo.outright AS o WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE o.leagueid = @LeagueId
				AND o.groupmatch = @RaceNo
				AND o.eventdate = @EventDate
				AND (ISNULL(o.Placing, 0) <> 0 OR o.IsSCR = 1)
			ORDER BY o.Placing
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.Outright14 WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @LeagueId = leagueid,
				@EventDate = eventdate
			FROM dbo.outright14 WITH (NOLOCK)
			WHERE orid = @MatchId

			INSERT INTO #tmpresult
			SELECT
				o.matchcode AS horseNo,
				NULL,
				CAST(o.groupmatch AS INT) AS racename,
				CASE WHEN o.placing = 0 THEN 5 ELSE ISNULL(o.Placing, 5) END place,
				l.sporttype,
				o.teamid AS horseid,
				o.odds,
				o.placeodds,
				o.leagueid AS meetingid,
				o.oddsstatus AS status,
				CONVERT(VARCHAR(10), o.IsFavor),
				o.IsSCR,
				o.FOddsStatus
			FROM dbo.outright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE o.leagueid = @LeagueId
				AND o.groupmatch = @RaceNo
				AND o.eventdate = @EventDate
				AND (ISNULL(o.Placing, 0) <> 0 OR o.IsSCR = 1)
			ORDER BY o.Placing
		END
		ELSE IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK) WHERE orid = @MatchId)
		BEGIN
			SELECT @LeagueId = leagueid,
				@EventDate = eventdate 
			FROM DBARC.bodb_Archive.dbo.Outright_bk WITH (NOLOCK)
			WHERE orid = @MatchId

			INSERT INTO #tmpresult
			SELECT
				bk.matchcode AS horseNo,
				NULL,
				CAST(bk.groupmatch AS INT) AS racename,
				CASE WHEN bk.placing = 0 THEN 5 ELSE ISNULL(bk.placing, 5) END place,
				l.sporttype,
				bk.teamid horseid,
				bk.odds,
				bk.placeodds,
				bk.leagueid AS meetingid,
				bk.oddsstatus status,
				CONVERT(VARCHAR(10), bk.IsFavor),
				bk.IsSCR,
				bk.FOddsStatus
			FROM DBARC.bodb_Archive.dbo.Outright_bk AS bk WITH (NOLOCK)
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = bk.leagueid
			WHERE bk.leagueid = @LeagueId 
				AND bk.groupmatch = @RaceNo
				AND bk.eventdate = @EventDate 
				AND (ISNULL(bk.placing, 0) <> 0 OR bk.isScr = 1)
			ORDER BY bk.placing
		END 

		-- Virtual Horse Racing
		IF EXISTS (SELECT TOP(1) 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE EventID = @MatchID)
		BEGIN
			INSERT INTO #tmpresult
			SELECT
				o.RacerNum AS horseNo,
				r.EventTime,
				NULL AS racename,
				o.Placing AS place,
				r.SportType,
				o.RacerID AS horseid,
				o.WinOdds AS odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus AS status,
				o.IsFavor,
				'' AS IsSCR,
				'' AS FOddsStatus
			FROM dbo.VSOutright AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(o.Placing, 0) <> 0)
			ORDER BY o.Placing
		END
		ELSE IF EXISTS (SELECT TOP(1) 1 FROM dbo.VSOutright14 WITH (NOLOCK) WHERE EventID = @MatchID)
		BEGIN
			INSERT INTO #tmpresult
			SELECT
				o.RacerNum AS horseNo,
				r.EventTime,
				NULL AS racename,
				o.Placing AS place,
				r.SportType,
				o.RacerID AS horseid,
				o.WinOdds AS odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus AS status,
				o.IsFavor,
				'' AS IsSCR,
				'' AS FOddsStatus
			FROM dbo.VSOutright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(o.Placing, 0) <> 0)
			ORDER BY o.Placing
		END
		ELSE
		BEGIN
			INSERT INTO #tmpresult
			SELECT
				o.RacerNum AS horseNo,
				r.EventTime,
				NULL AS racename,
				o.Placing AS place,
				r.SportType,
				o.RacerID AS horseid,
				o.WinOdds AS odds,
				o.placeodds,
				'' AS meetingid,
				o.EventStatus status,
				o.IsFavor,
				'' AS IsSCR,
				'' AS FOddsStatus
			FROM DBARC.bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(o.Placing, 0) <> 0)
			ORDER BY o.Placing
		END

		IF EXISTS (SELECT 1 FROM #tmpresult WHERE sporttype IN (151, 152, 153))
		BEGIN
			SELECT meetingid,
				racename,
				COUNT(place) rc
			INTO #DataSUM
			FROM #tmpresult
			WHERE place < 5
			GROUP BY meetingid, racename

			SELECT
				d.meetingid,
				d.racename,
				temp.results AS TF,
				temp2.results2 AS SCR
			INTO #tmp
			FROM #tmpresult AS d
				INNER JOIN #DataSum AS d2 ON d.meetingid = d2.meetingid AND d.racename = d2.racename
				CROSS APPLY (
					SELECT STUFF (
						(
						SELECT CAST(horseNo AS VARCHAR(10)) + ','
						FROM #tmpresult d
						WHERE d.meetingid = d2.meetingid
							AND d.racename = d2.racename
							AND d.IsFavor <> '0'
						FOR XML PATH(''), type).value('.','VARCHAR(max)')
						, 1, 2, ''
						)
					)temp(results)
				CROSS APPLY (
					SELECT STUFF (
						(
						SELECT CAST(horseNo AS VARCHAR(10)) + ','
						FROM #tmpresult d
						WHERE d.meetingid = d2.meetingid
							AND d.racename = d2.racename
							AND d.IsSCR <> 0
						FOR XML PATH(''), type).value('.','VARCHAR(max)')
						, 1, 2, ''
						)
					)temp2(results2)
			ORDER BY
				d.meetingid,
				d.racename,
				d.place

			SELECT DISTINCT
				d.*,
				d3.TF,
				d3.SCR,
				d2.rc AS [RowCount]
			FROM #tmpresult AS d
				INNER JOIN #DataSum AS d2 ON d.meetingid = d2.meetingid AND d.racename = d2.racename
				INNER JOIN #tmp AS d3 ON d.meetingid = d3.meetingid AND d.racename = d3.racename
			WHERE d.place < 5
			ORDER BY d.meetingid,
				d.racename,
				d.place

			DROP TABLE #DataSum
			DROP TABLE #tmp
		END
		ELSE IF EXISTS (SELECT 1 FROM #tmpresult WHERE sporttype IN (181, 182, 183, 184, 185))
		BEGIN
			SELECT kickofftime,
				COUNT(place) rc
			INTO #DataSUMVHR
			FROM #tmpresult
			GROUP BY kickofftime

			SELECT
				d.horseNo,
				d.KickoffTime,
				d.racename,
				d.place,
				d.sporttype,
				d.horseid,
				CASE d.sporttype * d.place --check whether the sport is Virtual Cycling & get the place
					WHEN 0 THEN 0		-- 0 * 185
					WHEN 370 THEN 0		-- 2 * 185
					WHEN 555 THEN 0		-- 3 * 185
					WHEN 740 THEN 0		-- 4 * 185
					ELSE d.odds
				END AS odds,
				CASE d.sporttype --check whether the sport is Virtual Speedway or not
					WHEN 183 THEN 0
					ELSE d.PlaceOdds
				END AS PlaceOdds,
				d.meetingid,
				d.oddsstatus,
				d.IsFavor,
				d.IsSCR,
				d.FOddsStatus,
				'' TF,
				'' SCR,
				d2.rc AS [RowCount]
			FROM #tmpresult AS d
				INNER JOIN #DataSumVHR AS d2 ON d.kickofftime = d2.kickofftime
			WHERE (d.place < 5 AND d.sporttype <> 183)
				OR (d.place < 2 AND d.sporttype = 183)
			ORDER BY d.MeetingId,
				d.KickOffTime,
				d.Place

			DROP TABLE #DataSumVHR
		END
		ELSE
		BEGIN
			SELECT * FROM #tmpresult
		END

		DROP TABLE #tmpresult
	END
END




 
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelMatchResult] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelMatchResult] TO [vnteam]
GO
