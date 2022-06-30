/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_Rpt_DailyWLDirect_Result]
	@MatchId		INT,
	@BetType		INT		= 0,
	@LiveIndicator	TINYINT	= 2,
	@TraderName		NVARCHAR(100) OUTPUT
AS

/*
	Created: Elodie
	Task: Get result in report 2h
	DB: DBACC.bodb02
	Original: Acc_BetList_SelMatchResult

	Param's Explanation:
		+ @LiveIndicator:
			0: Non-live
			1: Live
			2: All (Live & non-live)

	Revisions:
		- 20141021@Sophia: Get data of ResultDetail (Sporting Solution)
		- 20140414@Sophia: Support Bet Radar
		- 20170123@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70731]
		- 20170209@Kos: Don't support result detail anymore [#Redmine: 70731]
		- 20170323@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170802@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
		- 20171004@Kos: Use table TradingBettypeMapping instead of hardcode [Redmine: #83679]
		- 20181108@Kos: Support 2 new status Result Pending and Under Settlement [#Redmine: 104013]
					- Move eventstatus data transform to web (no change for Tennis)
		- 20181025@Kos: Support E-Sports 2 [Redmine: #100635]
		- 20191014@Kos: Support new table Trader [Redmine: #120746]
					- Add new param @LiveIndicator
		- 20191118@Kos: Support BMAIO [Redmine: #124017]
		- 20210224@Kos: Support Cricket AIO [Redmine: #151011]
		- 20210713@Kos: Support Beach Volleyball [Redmine: #157736]
		- 20210914@Kos: Support view result from League WL report [Redmine: #160196]
		- 20220630@Kos: Don't show map result for E-Sports [Redmine: #174251]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SportType	SMALLINT,
		@ChildMatchType	TINYINT,
		@ParentId		INT

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
		FROM bodb_Archive.dbo.match_bk WITH (NOLOCK)
		WHERE matchid = @MatchId
	END

	-- Switch to use parent match for Cricket child match (ChildMatchType = 200)
	SET @MatchId = CASE
						WHEN @SportType = 50 AND @ChildMatchType = 200 THEN @ParentId
						ELSE @MatchId
					END

	IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId)		-- Bettrans range
	BEGIN
		-- Get match info and result
		SELECT
			m.betstatus,
			m.hthomescore,
			m.htawayscore,
			DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) AS PlayTime,
			m.leagueid,
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
					CASE ISNULL(r.SettlementStatusID, 0)
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
			m.GoalRecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS Calculate,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			m.showtime
		FROM dbo.match AS m WITH (NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS r WITH (NOLOCK) ON r.MatchID = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		-- Get trader name
		IF @BetType <> 0
		BEGIN
			SELECT TOP(1) @TraderName = c.username
			FROM dbo.Dot_Admin_Assignment_Trader AS t WITH (NOLOCK)
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON t.TraderID = c.custid
			WHERE t.matchid = @MatchId
				AND t.bettype = @BetType
				AND (@LiveIndicator = 2 OR t.liveindicator = @LiveIndicator)
			ORDER BY
				t.UpdatedTime DESC,
				t.ID DESC
		END

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId

		-- Get result detail for Basketball, Tennis, E-Sports, Badminton main result only
		IF @SportType IN (2, 5)
		BEGIN
			SELECT
				MatchID,
				ResourceID,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND LEN(ResourceID) = 2
				AND (@SportType = 2
					OR (@SportType = 5 AND SettlementStatusID > 0))
			ORDER BY ResourceID ASC
		END
		ELSE IF @SportType = 43
		BEGIN
			SELECT
				MatchID,
				ResourceID,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailES WITH (NOLOCK)
			WHERE MatchID = @MatchId AND ResourceID = '00'
			ORDER BY ResourceID ASC
		END
		ELSE IF @SportType IN (9, 45, 50)		-- Badminton, Beach Volleyball, Cricket
		BEGIN
			SELECT
				MatchID,
				ResourceID,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailOS WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND (LEN(ResourceID) = 2
					OR (LEN(ResourceID) = 4 AND @SportType IN (9, 45)))
			ORDER BY ResourceID ASC
		END
	END
	ELSE IF EXISTS (SELECT 1 FROM dbo.match14 WITH (NOLOCK) WHERE matchid = @MatchId)	-- Bettrans14 range
	BEGIN
		-- Get match info and result
		SELECT
			m.betstatus,
			m.hthomescore,
			m.htawayscore,
			DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) AS PlayTime,
			m.leagueid,
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
					CASE ISNULL(r.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund'
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS EventStatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS Calculate,
			0 AS SettlementStatus,
			m.showtime
		FROM dbo.match14 AS m WITH (NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS r WITH (NOLOCK) ON r.MatchID = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		-- Get trader name
		IF @BetType <> 0
		BEGIN
			SELECT TOP(1) @TraderName = c.username
			FROM dbo.Dot_Admin_Assignment_Trader AS t WITH (NOLOCK)
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON t.TraderID = c.custid
			WHERE t.matchid = @MatchId
				AND t.bettype = @BetType
				AND (@LiveIndicator = 2 OR t.liveindicator = @LiveIndicator)
			ORDER BY
				t.UpdatedTime DESC,
				t.ID DESC
		END

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId

		-- Get result detail for Basketball, Tennis, E-Sports, Badminton main result only
		IF @SportType IN (2, 5)
		BEGIN
			SELECT
				MatchID,
				ResourceID,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail14 WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND LEN(ResourceID) = 2
				AND (@SportType = 2
					OR (@SportType = 5 AND SettlementStatusID > 0))
			ORDER BY ResourceID ASC
		END
		ELSE IF @SportType = 43
		BEGIN
			SELECT
				MatchID,
				ResourceID,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailES14 WITH (NOLOCK)
			WHERE MatchID = @MatchId AND ResourceID = '00'
			ORDER BY ResourceID ASC
		END
		ELSE IF @SportType IN (9, 45, 50)		-- Badminton, Beach Volleyball, Cricket
		BEGIN
			SELECT
				MatchID,
				ResourceID,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailOS14 WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND (LEN(ResourceID) = 2
					OR (LEN(ResourceID) = 4 AND @SportType IN (9, 45)))
			ORDER BY ResourceID ASC
		END
	END
	ELSE IF EXISTS (SELECT 1 FROM bodb_Archive.dbo.match_bk WITH (NOLOCK) WHERE matchid = @MatchId)	-- Bettrans_bk range
	BEGIN
		SELECT
			m.betstatus,
			m.hthomescore,
			m.htawayscore,
			DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) AS PlayTime,
			m.leagueid,
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
					CASE ISNULL(r.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund'
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS EventStatus,
			ISNULL(mr.refund, 0) IsRefund,
			ISNULL(mr.calrefund, 0) IsCalRefund,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.GoalRecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS Calculate,
			0 AS SettlementStatus
		FROM bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
			LEFT OUTER JOIN bodb_Archive.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN bodb_Archive.dbo.ResultDetail_bk AS r WITH (NOLOCK) ON r.MatchId = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		DECLARE @CutOffDate SMALLDATETIME = '2019-11-01 00:00:00'
		DECLARE @EventDate SMALLDATETIME

		SELECT @EventDate = eventdate
		FROM bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
		WHERE matchid = @MatchId

		IF @BetType <> 0
		BEGIN
			IF @EventDate < @CutOffDate
			BEGIN
				SELECT @TraderName = c.username
				FROM bodb_Archive.dbo.Dot_Admin_Assignment_Operator_bk AS o WITH (NOLOCK)
					INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON o.OperatorID = c.custid
					INNER JOIN DBDW.bodb_Account.dbo.TradingBettypeMapping AS m WITH (NOLOCK)
						ON o.OperatorType = m.OperatorType AND o.bettype = m.TradingBetType
				WHERE o.matchid = @MatchId AND m.TicketBetType = @BetType
			END
			ELSE
			BEGIN
				-- Get trader name
				SELECT TOP(1) @TraderName = c.username
				FROM bodb_Archive.dbo.Dot_Admin_Assignment_Trader_bk AS t WITH (NOLOCK)
					INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON t.TraderID = c.custid
				WHERE t.matchid = @MatchId
					AND t.bettype = @BetType
					AND (@LiveIndicator = 2 OR t.liveindicator = @LiveIndicator)
				ORDER BY
					t.UpdatedTime DESC,
					t.ID DESC
			END
		END

		-- Get sport type
		SELECT @SportType = sporttype
		FROM bodb_Archive.dbo.match_bk WITH (NOLOCK)
		WHERE matchid = @MatchId

		-- Get result detail for Basketball, Tennis, E-Sports, Badminton main result only
		IF @SportType IN (2, 5)
		BEGIN
			SELECT
				MatchID,
				ResourceID,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM bodb_Archive.dbo.ResultDetail_bk WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND LEN(ResourceID) = 2
				AND (@SportType = 2
					OR (@SportType = 5 AND SettlementStatusID > 0))
			ORDER BY ResourceID ASC
		END
		ELSE IF @SportType = 43
		BEGIN
			SELECT
				MatchID,
				ResourceID,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM bodb_Archive.dbo.ResultDetailES_bk WITH (NOLOCK)
			WHERE MatchID = @MatchId AND ResourceID = '00'
			ORDER BY ResourceID ASC
		END
		ELSE IF @SportType IN (9, 45, 50)		-- Badminton, Beach Volleyball, Cricket
		BEGIN
			SELECT
				MatchID,
				ResourceID,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM bodb_Archive.dbo.ResultDetailOS_bk WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND (LEN(ResourceID) = 2
					OR (LEN(ResourceID) = 4 AND @SportType IN (9, 45)))
			ORDER BY ResourceID ASC
		END
	END
END
GO
