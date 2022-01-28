/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

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
		- 20180806@Kos: Don't support Racing anymore [#Redmine: 99378]
		- 20181012@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
					- Move eventstatus data transform to web (no change for Tennis)
		- 20181122@Kos: Support E-Sports 2 [#Redmine: 100721]
		- 20190325@Kos: Hotfix - Bet ID contain '8' [Redmine: #112376]
		- 20190814@Kos: Support PH AIO phase 4b [Redmine: #118300]
		- 20191107@Kos: Support Badminton AIO phase 2 [Redmine: #120336]
		- 20191206@Kos: Show Instant Calculation Result for Corner Bettypes [Redmine: #124682]
		- 20200107@Kos: Support PH AIO phase 5 [Redmine: #126005]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20201006@Razor: Support Time Machine Over/Under [Redmine: #141998]
		- 20210223@Kos: Support Cricket AIO [Redmine: #150386]
		- 20210420@Kos: Support Time Machine Over/Under [Redmine: #153302]
		- 20210630@Kos: Support Beach Volleyball [Redmine: #157296]
		- 20220225@Kos: Support E-Sports phase 4 [Redmine: #167094]

		*******************
		sample test case:
			exec Lrf_BetList_SelMatchResult @MatchID=10514601, @RaceNo=default, @BetType=1324, @Betid='801'
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @ResultDetail TABLE (
		MatchId				INT,
		ResourceId			VARCHAR(20),
		HomeValue			VARCHAR(50),
		AwayValue			VARCHAR(50),
		ResultStatusId		TINYINT,
		SettlementStatusId	TINYINT,
		OtherInfo			VARCHAR(50))

	IF @RaceNo IS NULL
	BEGIN
		DECLARE @ResourceId	VARCHAR(20),
			@SportType		SMALLINT,
			@ChildMatchType	TINYINT,
			@ParentId		INT

		-- Get result detail of bet type 221 in case of 225
		IF @BetType = 225
			SET @BetType = 221

		-- Get sport type, child match type
		IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId)
		BEGIN
			SELECT @SportType = sporttype,
				@ParentId = ParentID,
				@ChildMatchType = ChildMatchType
			FROM dbo.match WITH (NOLOCK)
			WHERE matchid = @MatchId
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.match14 WITH (NOLOCK) WHERE matchid = @MatchId)
		BEGIN
			SELECT @SportType = sporttype,
				@ParentId = ParentID,
				@ChildMatchType = ChildMatchType
			FROM dbo.match14 WITH (NOLOCK)
			WHERE matchid = @MatchId
		END
		ELSE
		BEGIN
			SELECT @SportType = sporttype,
				@ParentId = ParentID,
				@ChildMatchType = ChildMatchType
			FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK)
			WHERE matchid = @MatchId
		END

		-- Switch to use parent match for Cricket child match (ChildMatchType = 200)
		SET @MatchId = CASE
							WHEN @SportType = 50 AND @ChildMatchType = 200 THEN @ParentId
							ELSE @MatchId
						END

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
					ELSE m.eventstatus
				END AS EventStatus,
				ISNULL(mr.refund, 0) AS IsRefund,
				ISNULL(mr.calrefund, 0) AS IsCalRefund,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				ISNULL(m.showtime, '') AS showtime,
				m.homeid2
			FROM dbo.match AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.MatchID = m.matchid AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId

			SELECT @ResourceId = CASE
									WHEN @SportType = 5 THEN LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
									WHEN @BetType = 395 THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 2)
									ELSE RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)
								END

			-- Get result detail
			IF @SportType NOT IN (9, 43, 45, 50, 193)
			BEGIN
				INSERT INTO @ResultDetail
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
								OR d.ResourceID LIKE '227%'
								OR d.ResourceID LIKE '228%'
								OR d.ResourceID LIKE '229%')
							AND d.ResourceId LIKE f.ResourceID
							AND (@BetType NOT IN (486, 487, 395, 385, 384, 383, 382, 381)
								OR d.ResourceId IN ('08', '09')
								OR d.ResourceId LIKE '%' + @ResourceId))
						OR (@SportType = 2						-- Basketball
							AND (LEN(d.ResourceId) = 2
								OR (d.SettlementStatusID > 0
									AND d.ResourceId LIKE f.ResourceID
									AND (@BetType NOT IN (606, 607, 613, 617)
										OR d.ResourceId LIKE '%' + @ResourceId)))))
			END
			ELSE IF @SportType IN (9, 45, 50)		-- Badminton, Cricket, Beach Volleyball
			BEGIN
				INSERT INTO @ResultDetail
				SELECT
					d.MatchId,
					d.ResourceId,
					d.HomeValue,
					d.AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM dbo.ResultDetailOS AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
						ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
				WHERE d.MatchId = @MatchId
					AND (LEN(d.ResourceId) = 2
						OR (LEN(d.ResourceId) = 4 AND @SportType IN (9, 45))
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND d.ResourceId LIKE '%' + @ResourceId))
				ORDER BY d.ResourceID ASC
			END
			ELSE IF @SportType = 43		-- E-Sports
			BEGIN
				INSERT INTO @ResultDetail
				SELECT
					d.MatchId,
					d.ResourceId,
					d.HomeValue,
					d.AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM dbo.ResultDetailES AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
						ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
				WHERE d.MatchId = @MatchId
					AND (LEN(d.ResourceId) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND d.ResourceId LIKE '%' + @ResourceId + CASE
																		WHEN @BetType = 9101 THEN '01'
																		WHEN @BetType = 9102 THEN '02'
																		WHEN @BetType = 9103 THEN '03'
																		WHEN @BetType = 9104 THEN '04'
																		WHEN @BetType = 9105 THEN '05'
																		WHEN @BetType = 9106 THEN '06'
																		WHEN @BetType = 9107 THEN '07'
																		WHEN @BetType = 9108 THEN '08'
																		WHEN @BetType = 9109 THEN '09'
																		WHEN @BetType = 9110 THEN '10'
																		WHEN @BetType = 9111 THEN '15'
																		WHEN @BetType = 9112 THEN '20'
																		ELSE ''
																	END))
			END
			ELSE
			BEGIN
				INSERT INTO @ResultDetail
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
			END
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
					ELSE m.eventstatus
				END AS EventStatus,
				ISNULL(mr.refund, 0) AS IsRefund,
				ISNULL(mr.calrefund, 0) AS IsCalRefund,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				0 AS SettlementStatus,
				ISNULL(m.showtime, '') AS showtime,
				m.homeid2
			FROM dbo.match14 AS m WITH (NOLOCK)
				LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId

			SELECT @ResourceId = CASE
									WHEN @SportType = 5 THEN LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
									WHEN @BetType = 395 THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 2)
									ELSE RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)
								END

			-- Get result detail
			IF @SportType NOT IN (9, 43, 45, 50, 193)
			BEGIN
				INSERT INTO @ResultDetail
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
								OR d.ResourceID LIKE '227%'
								OR d.ResourceID LIKE '228%'
								OR d.ResourceID LIKE '229%')
							AND d.ResourceId LIKE f.ResourceID
							AND (@BetType NOT IN (486, 487, 395, 385, 384, 383, 382, 381)
								OR d.ResourceId IN ('08', '09')
								OR d.ResourceId LIKE '%' + @ResourceId))
						OR (@SportType = 2						-- Basketball
							AND (LEN(d.ResourceId) = 2
								OR (d.SettlementStatusID > 0
									AND d.ResourceId LIKE f.ResourceID
									AND (@BetType NOT IN (606, 607, 613, 617)
										OR d.ResourceId LIKE '%' + @ResourceId)))))
			END
			ELSE IF @SportType IN (9, 45, 50)		-- Badminton, Cricket, Beach Volleyball
			BEGIN
				INSERT INTO @ResultDetail
				SELECT
					d.MatchId,
					d.ResourceId,
					d.HomeValue,
					d.AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM dbo.ResultDetailOS14 AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
						ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
				WHERE d.MatchId = @MatchId
					AND (LEN(d.ResourceId) = 2
						OR (LEN(d.ResourceId) = 4 AND @SportType IN (9, 45))
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND d.ResourceId LIKE '%' + @ResourceId))
				ORDER BY d.ResourceID ASC
			END
			ELSE IF @SportType = 43		-- E-Sports
			BEGIN
				INSERT INTO @ResultDetail
				SELECT
					d.MatchId,
					d.ResourceId,
					d.HomeValue,
					d.AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM dbo.ResultDetailES14 AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
						ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
				WHERE d.MatchId = @MatchId
					AND (LEN(d.ResourceId) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND d.ResourceId LIKE '%' + @ResourceId + CASE
																		WHEN @BetType = 9101 THEN '01'
																		WHEN @BetType = 9102 THEN '02'
																		WHEN @BetType = 9103 THEN '03'
																		WHEN @BetType = 9104 THEN '04'
																		WHEN @BetType = 9105 THEN '05'
																		WHEN @BetType = 9106 THEN '06'
																		WHEN @BetType = 9107 THEN '07'
																		WHEN @BetType = 9108 THEN '08'
																		WHEN @BetType = 9109 THEN '09'
																		WHEN @BetType = 9110 THEN '10'
																		WHEN @BetType = 9111 THEN '15'
																		WHEN @BetType = 9112 THEN '20'
																		ELSE ''
																	END))
			END
			ELSE
			BEGIN
				INSERT INTO @ResultDetail
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
			END
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
					ELSE m.eventstatus
				END AS EventStatus,
				ISNULL(mr.refund, 0) AS IsRefund,
				ISNULL(mr.calrefund, 0) AS IsCalRefund,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.goalrecord,
				ISNULL(mr.IsHTCal, 0) AS IsHTCal,
				ISNULL(mr.calculate, 0) AS calculate,
				0 AS SettlementStatus,
				ISNULL(m.showtime, '') AS showtime,
				m.homeid2
			FROM DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
				LEFT OUTER JOIN DBARC.bodb_Archive.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
				LEFT JOIN DBARC.bodb_Archive.dbo.ResultDetail_BK AS d WITH (NOLOCK) ON d.matchID = M.MatchID AND d.ResourceId = '00'
			WHERE m.matchid = @MatchId

			SELECT @ResourceId = CASE
									WHEN @SportType = 5 THEN LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
									WHEN @BetType = 395 THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 2)
									ELSE RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)
								END

			-- Get result detail
			IF @SportType NOT IN (9, 43, 45, 50, 193)
			BEGIN
				INSERT INTO @ResultDetail
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
								OR d.ResourceID LIKE '227%'
								OR d.ResourceID LIKE '228%'
								OR d.ResourceID LIKE '229%')
							AND d.ResourceId LIKE f.ResourceID
							AND (@BetType NOT IN (486, 487, 395, 385, 384, 383, 382, 381)
								OR d.ResourceId IN ('08', '09')
								OR d.ResourceId LIKE '%' + @ResourceId))
						OR (@SportType = 2						-- Basketball
							AND (LEN(d.ResourceId) = 2
								OR (d.SettlementStatusID > 0
									AND d.ResourceId LIKE f.ResourceID
									AND (@BetType NOT IN (606, 607, 613, 617)
										OR d.ResourceId LIKE '%' + @ResourceId)))))
			END
			ELSE IF @SportType IN (9, 45, 50)		-- Badminton, Cricket, Beach Volleyball
			BEGIN
				INSERT INTO @ResultDetail
				SELECT
					d.MatchId,
					d.ResourceId,
					d.HomeValue,
					d.AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM DBARC.bodb_Archive.dbo.ResultDetailOS_bk AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
						ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
				WHERE d.MatchId = @MatchId
					AND (LEN(d.ResourceId) = 2
					OR (LEN(d.ResourceId) = 4 AND @SportType IN (9, 45))
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND d.ResourceId LIKE '%' + @ResourceId))
				ORDER BY d.ResourceID ASC
			END
			ELSE IF @SportType = 43	-- E-Sports
			BEGIN
				INSERT INTO @ResultDetail
				SELECT
					d.MatchId,
					d.ResourceId,
					d.HomeValue,
					d.AwayValue,
					d.ResultStatusID,
					d.SettlementStatusID,
					d.OtherInfo
				FROM DBARC.bodb_Archive.dbo.ResultDetailES_bk AS d WITH (NOLOCK)
					LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
						ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
				WHERE d.MatchId = @MatchId
					AND (LEN(d.ResourceId) = 2
						OR (d.SettlementStatusID > 0
							AND d.ResourceId LIKE f.ResourceID
							AND d.ResourceId LIKE '%' + @ResourceId + CASE
																		WHEN @BetType = 9101 THEN '01'
																		WHEN @BetType = 9102 THEN '02'
																		WHEN @BetType = 9103 THEN '03'
																		WHEN @BetType = 9104 THEN '04'
																		WHEN @BetType = 9105 THEN '05'
																		WHEN @BetType = 9106 THEN '06'
																		WHEN @BetType = 9107 THEN '07'
																		WHEN @BetType = 9108 THEN '08'
																		WHEN @BetType = 9109 THEN '09'
																		WHEN @BetType = 9110 THEN '10'
																		WHEN @BetType = 9111 THEN '15'
																		WHEN @BetType = 9112 THEN '20'
																		ELSE ''
																	END))
			END
			ELSE
			BEGIN
				INSERT INTO @ResultDetail
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
			END
		END

		-- Don't show ResourceID '4860X', '488', '490' if ResourceID '08' exists
		IF EXISTS (SELECT 1 FROM @ResultDetail WHERE ResourceId = '08')
		BEGIN
			DELETE FROM @ResultDetail
			WHERE ResourceId IN ('488', '490') OR ResourceId LIKE '486%'
		END

		-- Don't show ResourceID '4870X', '489' if ResourceID '09' exists
		IF EXISTS (SELECT 1 FROM @ResultDetail WHERE ResourceId = '09')
		BEGIN
			DELETE FROM @ResultDetail
			WHERE ResourceId = '489' OR ResourceId LIKE '487%'
		END

		-- Don't show ResourceID '09' if ResourceID '490' exists
		IF EXISTS (SELECT 1 FROM @ResultDetail WHERE ResourceId = '490')
		BEGIN
			DELETE FROM @ResultDetail
			WHERE ResourceId = '09'
		END

		-- Return '08' FT Sequence, '09' 1H Sequence only if at least a goal/corner scored
		DELETE FROM @ResultDetail
		WHERE ResourceId IN ('08', '09')
			AND HomeValue NOT LIKE '%a%'
			AND HomeValue NOT LIKE '%h%'

		SELECT
			MatchId,
			@BetType AS BetType,
			ResourceId,
			HomeValue,
			AwayValue,
			ResultStatusId,
			SettlementStatusId,
			OtherInfo
		FROM @ResultDetail
		ORDER BY ResourceId ASC
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
			ORDER BY o.Placing ASC
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
				INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(o.Placing, 0) <> 0)
			ORDER BY o.Placing ASC
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
				INNER JOIN DBARC.bodb_Archive.dbo.VSRaceInfo_bk AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventID = @MatchID AND (ISNULL(o.Placing, 0) <> 0)
			ORDER BY o.Placing ASC
		END

		IF EXISTS (SELECT 1 FROM #tmpresult WHERE sporttype IN (181, 182, 183, 184, 185))
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
			ORDER BY d.MeetingId ASC,
				d.KickOffTime ASC,
				d.Place ASC

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
