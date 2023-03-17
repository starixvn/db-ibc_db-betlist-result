/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_SelMatchResult]
	@MatchId	INT,
	@BetType	SMALLINT	= NULL,
	@BetId		BIGINT		= NULL,
	@Transdesc	NVARCHAR(1000)	= NULL
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
		- 20111003@Sophia: Add column IsPending Pending Status
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
		- 20170323@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170802@Kos: Change sporttype data type to SMALLINT [Redmine: #73545]
		- 20171012@Kos: Support PH AIO Phase 3 [Redmine: #82403]
		- 20180201@Kos: Don't support Racing and Virtual Horse Racing anymore [#Redmine: 86086]
					- Remove param @RaceNo
		- 20180320@Kos: Support Fast Market 2 [Redmine: #90708]
		- 20180410@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20180423@Kos: Hotfix - redundant Result Detail in result popup [Redmine: #94133]
		- 20180927@Kos: Support new status Result Pending and Under Settlement [#Redmine: 101949]
					- Move eventstatus data transform to web (no change for Tennis)
		- 20181122@Kos: Support E-Sports phase 2 [Redmine: #101047]
		- 20190325@Kos: Hotfix - Bet ID contain '8' [Redmine: #110599]
		- 20190806@Kos: Support PH AIO phase 4b [Redmine: #115235]
		- 20191014@Kos: Support Badminton AIO phase 2 [Redmine: #120381]
		- 20191204@Kos: Show Instant Calculation Result for Corner Bettypes [Redmine: #124682]
		- 20191220@Kos: Support PH AIO phase 5 [Redmine: #124455]
		- 20201006@Razor: Support Time Machine Over/Under [Redmine: #141998]
		- 20210223@Kos: Support Cricket AIO [Redmine: #148962]
		- 20210414@Razor: Support Time Machine HDP [Redmine: #152749]
		- 20210630@Razor: Support Beach Volleyball [Redmine: #156540]
		- 20220120@Razor: Support E-Sports phase 4 [Redmine: #166326]
		- 20220310@Razor: Support Cricket AIO 2 [Redmine: #166334]
		- 20220622@Razor: Support More map for eSports [Redmine: #174251]
		- 20220711@Razor: Support Volleyball AIO [Redmine: #173861]
		- 20230316@Razor: Change HT Score display for Soccer [Redmine: #181331]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @ResultDetail TABLE (
		MatchId				INT,
		ResourceId			VARCHAR(20),
		HomeValue			VARCHAR(50),
		AwayValue			VARCHAR(50),
		ResultStatusID		TINYINT,
		SettlementStatusID	TINYINT,
		OtherInfo			VARCHAR(2000))

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
				ELSE m.eventstatus
			END AS eventstatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			ISNULL(mr.NoHTScore, 0) AS NoHTScore,
			m.showtime
		FROM dbo.match AS m WITH (NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'
		WHERE m.matchid = @MatchId

		SELECT @ResourceId = CASE
								WHEN @SportType = 5 THEN LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
								WHEN @BetType = 395 THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 2)
								WHEN @BetType = 9001 AND @BetId LIKE '80%' THEN 'M' + RIGHT(CONVERT(VARCHAR(20), @BetId), 1)
								WHEN @BetType IN (3903, 3904, 3905) AND @BetId LIKE '80%' THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 1) + '15'
								ELSE RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)
							END

		-- Get result detail
		IF @SportType NOT IN (6, 9, 43, 45, 50, 193)
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
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND ((@SportType = 5
						AND d.SettlementStatusID > 0
						AND CASE
								WHEN @BetType <> 1324 THEN 2
								ELSE
									CASE
										WHEN @BetType = 1324 AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
										ELSE 0
									END
							END = LEN(d.ResourceId))
					OR (@SportType = 1
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
					OR (@SportType = 2
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceId LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceId LIKE '%' + @ResourceId)))))
		END
		ELSE IF @SportType IN (6, 9, 45, 50)		-- Volleyball, Badminton, Beach Volleyball, Cricket
		BEGIN
			INSERT INTO @ResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				CASE
					WHEN @Bettype IN (9662, 9664, 9666) AND d.ResourceId LIKE '9662%' THEN @Transdesc
					WHEN @Bettype IN (9663, 9665, 9667) AND d.ResourceId LIKE '9663%' THEN @Transdesc
					ELSE d.HomeValue
				END AS HomeValue,
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
					OR (@SportType = 6 AND d.ResourceId LIKE '010%')
					OR (d.SettlementStatusID > 0
						AND d.ResourceId LIKE f.ResourceID
						AND d.ResourceId LIKE '%' + @ResourceId))
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
				AND (d.ResourceId = '00'
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
				ELSE m.eventstatus
			END AS eventstatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			0 AS SettlementStatus,
			ISNULL(mr.NoHTScore, 0) AS NoHTScore,
			m.showtime
		FROM dbo.match14 AS m WITH (NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'
		WHERE m.matchid = @MatchId

		SELECT @ResourceId = CASE
								WHEN @SportType = 5 THEN LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
								WHEN @BetType = 395 THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 2)
								WHEN @BetType = 9001 AND @BetId LIKE '80%' THEN 'M' + RIGHT(CONVERT(VARCHAR(20), @BetId), 1)
								WHEN @BetType IN (3903, 3904, 3905) AND @BetId LIKE '80%' THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 1) + '15'
								ELSE RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)
							END

		-- Get result detail
		IF @SportType NOT IN (6, 9, 43, 45, 50, 193)
		BEGIN
			INSERT INTO @ResultDetail
			SELECT
				d.MatchID,
				d.ResourceID,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail14 AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceID LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND ((@SportType = 5
						AND d.SettlementStatusID > 0
						AND CASE
								WHEN @BetType <> 1324 THEN 2
								ELSE
									CASE
										WHEN @BetType = 1324 AND LEFT(d.ResourceID, 2) = @ResourceId THEN 4
										ELSE 0
									END
							END = LEN(d.ResourceID))
					OR (@SportType = 1
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
						AND d.ResourceID LIKE f.ResourceID
						AND (@BetType NOT IN (486, 487, 395, 385, 384, 383, 382, 381)
							OR d.ResourceId IN ('08', '09')
							OR d.ResourceID LIKE '%' + @ResourceId))
					OR (@SportType = 2
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceId LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceId LIKE '%' + @ResourceId)))))
		END
		ELSE IF @SportType IN (6, 9, 45, 50)		-- Volleyball, Badminton, Beach Volleyball, Cricket
		BEGIN
			INSERT INTO @ResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				CASE
					WHEN @Bettype IN (9662, 9664, 9666) AND d.ResourceId LIKE '9662%' THEN @Transdesc
					WHEN @Bettype IN (9663, 9665, 9667) AND d.ResourceId LIKE '9663%' THEN @Transdesc
					ELSE d.HomeValue
				END AS HomeValue,
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
					OR (@SportType = 6 AND d.ResourceId LIKE '010%')
					OR (d.SettlementStatusID > 0
						AND d.ResourceId LIKE f.ResourceID
						AND d.ResourceId LIKE '%' + @ResourceId))
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
				AND (d.ResourceId = '00'
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
			DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) playtime,
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
				ELSE m.eventstatus
			END AS eventstatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			0 AS SettlementStatus,
			ISNULL(mr.NoHTScore, 0) AS NoHTScore,
			m.showtime
		FROM DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
			LEFT OUTER JOIN DBARC.bodb_Archive.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN DBARC.bodb_Archive.dbo.ResultDetail_bk AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'
		WHERE m.matchid = @MatchId

		SELECT @ResourceId = CASE
								WHEN @SportType = 5 THEN LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
								WHEN @BetType = 395 THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 2)
								WHEN @BetType = 9001 AND @BetId LIKE '80%' THEN 'M' + RIGHT(CONVERT(VARCHAR(20), @BetId), 1)
								WHEN @BetType IN (3903, 3904, 3905) AND @BetId LIKE '80%' THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 1) + '15'
								ELSE RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)
							END

		-- Get result detail
		IF @SportType NOT IN (6, 9, 43, 45, 50, 193)
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
			FROM DBARC.bodb_Archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND ((@SportType = 5
						AND d.SettlementStatusID > 0
						AND CASE
								WHEN @BetType <> 1324 THEN 2
								ELSE
									CASE
										WHEN @BetType = 1324 AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
										ELSE 0
									END
							END = LEN(d.ResourceId))
					OR (@SportType = 1
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
					OR (@SportType = 2
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceId LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceId LIKE '%' + @ResourceId)))))
		END
		ELSE IF @SportType IN (6, 9, 45, 50)		-- Volleyball, Badminton, Beach Volleyball, Cricket
		BEGIN
			INSERT INTO @ResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				CASE
					WHEN @Bettype IN (9662, 9664, 9666) AND d.ResourceId LIKE '9662%' THEN @Transdesc
					WHEN @Bettype IN (9663, 9665, 9667) AND d.ResourceId LIKE '9663%' THEN @Transdesc
					ELSE d.HomeValue
				END AS HomeValue,
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
					OR (@SportType = 6 AND d.ResourceId LIKE '010%')
					OR (d.SettlementStatusID > 0
						AND d.ResourceId LIKE f.ResourceID
						AND d.ResourceId LIKE '%' + @ResourceId))
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
			FROM DBARC.bodb_Archive.dbo.ResultDetailES_bk AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND (d.ResourceId = '00'
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
		ResultStatusID,
		SettlementStatusID,
		OtherInfo
	FROM @ResultDetail
	ORDER BY ResourceId ASC
END
GO
