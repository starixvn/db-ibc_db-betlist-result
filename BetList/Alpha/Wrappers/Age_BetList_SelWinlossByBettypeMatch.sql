/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet, wsv_alp,bodbDownlineNetView, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossByBettypeMatch]
	@MatchId		INT,
	@CustId			INT			= NULL,
	@Username		VARCHAR(50)	= NULL,
	@RoleId			TINYINT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BetType		SMALLINT,
	@LiveIndicator	BIT			= 0
AS

/*
	Created: 20181115@Kos
	Task: Match Win Loss Bet List in Alpha
	DB: DBAGE.bodb02
	Revisions:
		- 20181115@Kos: Create new [#Redmine: 103577]
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190506@Kos: Show match KO time for single ticket [Redmine: #112092]
		- 20190524@Kos: Support BetBuilder [Redmine: #106905]
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20200214@Kos: Fix performance issue with f_GroupBettype func [Redmine: #128448]
		- 20200422@Kos: Support status Delay Payout [Redmine: #132629]
		- 20210208@Kos: Support Cricket AIO [Redmine: 148963]
					- Add new input params @FromDate SMALLDATETIME, @ToDate SMALLDATETIME, @MoveBetsDay SMALLDATETIME
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211130@Razor: Support new Cash out model [Redmine: #164903]
		- 20221122@Kos: Hotfix - Sorting not work [Redmine: #180779]
		- 20230727@Razor: Support Virtual Sports 3 [Redmine: #189205]
		- 20230927@Razor: Support show max payout [Redmine: #194491]
		- 20231027@Razor: Support new bettype of Virtual Sport 3 (LG) [Redmine: #194634]
		- 20231101@Razor: Return Device Type info [Redmine: #192667]
		- 20231129@Razor: Support Project 777 - return LeagueGroupId [Redmine: #194591]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @GroupBetType TABLE (BetType INT, GroupTypeId INT)

	INSERT INTO @GroupBetType
	SELECT
		bettype,
		GroupTypeId
	FROM dbo.f_GroupBettype()

	-- Gather SportBetTypeMatrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Support Sportsbook, Number Game, Virtual Sports, Betradar Virtual Sports, Virtual Sports 3 only
	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest) AS s
	WHERE ProductID IN (1, 3, 5, 27, 77)
		AND BetType NOT IN (901, 902, 903, 904)
		AND (BetType = @BetType
			OR EXISTS (SELECT 1 FROM @GroupBetType AS f WHERE f.GroupTypeId = @BetType AND f.BetType = s.BetType))

	DECLARE @IsBet14	BIT = 0,
		@EventDate		DATETIME,
		@SportType		SMALLINT,
		@ChildMatchType TINYINT,
		@ParentId		INT

	SELECT
		@EventDate = eventdate,
		@SportType = sporttype,
		@ParentId = ParentID
	FROM dbo.match WITH (NOLOCK)
	WHERE matchid = @MatchId AND eventdate > @MoveBetsDay

	IF @EventDate IS NULL
	BEGIN
		SET @IsBet14 = 1

		SELECT
			@EventDate = eventdate,
			@SportType = sporttype,
			@ParentId = ParentID
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId
	END

	DECLARE @Match TABLE(MatchId INT, EventDate DATETIME)

	IF @SportType = 50 AND @ParentId IS NULL	-- Cricket, parent match
	BEGIN
		INSERT INTO @Match
		SELECT DISTINCT
			MatchId,
			EventDate
		FROM dbo.match WITH (NOLOCK)
		WHERE ParentID = @MatchId
			AND sporttype = @SportType
			AND eventdate BETWEEN @FromDate AND @ToDate
			AND ChildMatchType = 200
		UNION
		SELECT DISTINCT
			MatchId,
			EventDate
		FROM dbo.match14 WITH (NOLOCK)
		WHERE ParentID = @MatchId
			AND sporttype = @SportType
			AND eventdate BETWEEN @FromDate AND @ToDate
			AND ChildMatchType = 200

		INSERT INTO @Match
		SELECT @MatchId, @EventDate
	END

	IF @CustId IS NULL
	BEGIN
		SELECT @CustId = custid
		FROM dbo.Customer WITH (NOLOCK)
		WHERE username = @Username
	END

	DECLARE @Data TABLE (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Username			NVARCHAR(50),
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsType			TINYINT,
		OddsId				INT,
		Odds				MONEY,
		MOdds				MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		WinLost				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		PlayerComm			MONEY,
		Comm				MONEY,
		AComm				MONEY,
		SComm				MONEY,
		APositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		SPositionTaking		SMALLMONEY,
		TPositionTaking		SMALLMONEY,
		ADiscount			SMALLMONEY,
		MDiscount			SMALLMONEY,
		SDiscount			SMALLMONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		FinalHomeScore		SMALLINT,
		FinalAwayScore		SMALLINT,
		HtHomeScore			SMALLINT,
		HtAwayScore			SMALLINT,
		Ip					VARCHAR(45),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		Currency			NVARCHAR(50),
		ExtraInfo			VARCHAR(1000),
		BetdaqId			BIGINT,
		DeviceType			TINYINT,
		LeagueGroupId		SMALLINT
	);

	DECLARE @Tickets TABLE (
		TransId	BIGINT,
		Product	VARCHAR(30)
	)

	DECLARE @FDate	SMALLDATETIME,
		@TDate		SMALLDATETIME

	-- bettrans range
	IF @IsBet14 = 0
		OR (@SportType = 50
			AND @ParentId IS NULL
			AND @ToDate > @MoveBetsDay)		-- Cricket main match
	BEGIN
		IF @SportType = 50 AND @ParentId IS NULL	-- Cricket main match
		BEGIN
			SET @FDate = CASE
							WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
							ELSE @FromDate
						END

			IF @RoleId = 2		-- Agent
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						ELSE 'Unknown'
					END AS Product
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
					INNER JOIN @Match AS m ON m.matchid = b.matchid
				WHERE b.recommend = @CustId
					AND b.winlostdate BETWEEN @FDate AND @ToDate
					AND b.statusID NOT IN (0, 1)
			END

			IF @RoleId = 3		-- Master
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						ELSE 'Unknown'
					END AS Product
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_MRecommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
					INNER JOIN @Match AS m ON m.matchid = b.matchid
				WHERE b.mrecommend = @CustId
					AND b.winlostdate BETWEEN @FDate AND @ToDate
					AND b.statusID NOT IN (0, 1)
			END

			IF @RoleId = 4		-- Super
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						ELSE 'Unknown'
					END AS Product
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_SRecommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
					INNER JOIN @Match AS m ON m.matchid = b.matchid
				WHERE b.srecommend = @CustId
					AND b.winlostdate BETWEEN @FDate AND @ToDate
					AND b.statusID NOT IN (0, 1)
			END
		END
		ELSE	-- Others
		BEGIN
			IF @RoleId = 2		-- Agent
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'		-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'		-- Virtual Sports:: sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'	-- Betradar Virtual Sports
						WHEN s.EventType = 1 AND s.ProductID = 77 THEN 'LG'		-- Virtual Sports 3
						ELSE 'Unknown'
					END AS Product
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_Recommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				WHERE b.recommend = @CustId
					AND b.winlostdate = @EventDate
					AND b.matchid = @MatchId
					AND b.statusID NOT IN (0, 1)
			END

			IF @RoleId = 3		-- Master
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'		-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'		-- Virtual Sports:: sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'	-- Betradar Virtual Sports
						WHEN s.EventType = 1 AND s.ProductID = 77 THEN 'LG'		-- Virtual Sports 3
						ELSE 'Unknown'
					END AS Product
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_MRecommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				WHERE b.mrecommend = @CustId
					AND b.winlostdate = @EventDate
					AND b.matchid = @MatchId
					AND b.statusID NOT IN (0, 1)
			END

			IF @RoleId = 4		-- Super
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'		-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'		-- Virtual Sports:: sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'	-- Betradar Virtual Sports
						WHEN s.EventType = 1 AND s.ProductID = 77 THEN 'LG'		-- Virtual Sports 3
						ELSE 'Unknown'
					END AS Product
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_SRecommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				WHERE b.srecommend = @CustId
					AND b.winlostdate = @EventDate
					AND b.matchid = @MatchId
					AND b.statusID NOT IN (0, 1)
			END
		END

		IF @LiveIndicator IS NOT NULL
			AND EXISTS (SELECT TOP(1) 1 FROM @Tickets WHERE Product = 'NG')
		BEGIN
			DELETE c
			FROM @Tickets AS c
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK, INDEX = PK_bettrans) ON c.TransId = b.transid
			WHERE c.Product = 'NG' AND b.liveindicator <> @LiveIndicator
		END

		INSERT INTO @Data (
			TransId,
			RefNo,
			CustId,
			Username,
			SportType,
			BetType,
			BetId,
			BetTeam,
			Hdp1,
			Hdp2,
			OddsType,
			OddsId,
			Odds,
			MOdds,
			Stake,
			Actual_Stake,
			Status,
			SettlementStatus,
			TransDate,
			WinLostDate,
			WinLost,
			AWinLost,
			MWinLost,
			SWinLost,
			PlayerComm,
			Comm,
			AComm,
			SComm,
			APositionTaking,
			MPositionTaking,
			SPositionTaking,
			TPositionTaking,
			ADiscount,
			MDiscount,
			SDiscount,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			FinalHomeScore,
			FinalAwayScore,
			HtHomeScore,
			HtAwayScore,
			Ip,
			LeagueId,
			MatchId,
			MatchCode,
			EventDate,
			HomeId,
			AwayId,
			BetStatus,
			IsNeutral,
			ShowTime,
			BetCheck,
			ComStatus,
			TransDesc,
			OddsSpread,
			Currency,
			ExtraInfo,
			BetdaqId,
			DeviceType,
			LeagueGroupId)
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.username,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.sporttype
				ELSE 0
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			CASE
				WHEN c.Product IN ('SB', 'VS', 'VS2', 'LG') THEN b.hdp2
				ELSE 0
			END AS Hdp2,
			b.oddstype,
			b.oddsid,
			b.odds,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.modds
				ELSE 0
			END AS MOdds,
			b.stake,
			b.actual_stake,
			b.status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.winlost - b.actual_stake AS WinLost,
			b.awinlost,
			b.mwinLost,
			b.swinlost,
			b.playercomm,
			b.comm - b.playercomm AS Comm,
			b.acomm - b.comm AS AComm,
			b.scomm - b.acomm AS SComm,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.tpositiontaking,
			b.discount AS ADiscount,
			b.adiscount AS MDiscount,
			b.sdiscount AS SDiscount,
			b.liveindicator,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.livehomescore
				ELSE 0
			END AS LiveHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.liveawayscore
				ELSE 0
			END AS LiveAwayScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.finalhomescore
				ELSE 0
			END AS FinalHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.finalawayscore
				ELSE 0
			END AS FinalAwayScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.hthomescore
				ELSE 0
			END AS HtHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.htawayscore
				ELSE 0
			END AS HtAwayScore,
			b.ip,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.leagueid
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.matchid
				ELSE 0
			END AS MatchId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN c.Product = 'SB' THEN m.GlobalShowTime
				WHEN c.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.eventdate
				ELSE b.winlostdate
			END AS EventDate,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.homeid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			CASE
				WHEN c.Product IN ('VS', 'VS2', 'LG') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN c.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			CASE
				WHEN c.Product IN ('SB', 'VS2', 'LG') THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			b.currencyname AS Currency,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END,
			b.DeviceType,
			l.LeagueGroupId
		FROM @Tickets AS c
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK, INDEX = PK_bettrans) ON b.transid = c.TransId
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') AND b.matchid = m.matchid
			LEFT JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
	END

	-- bettrans14 range
	IF @IsBet14 = 1
		OR (@SportType = 50
			AND @ParentId IS NULL
			AND @ToDate <= @MoveBetsDay)		-- Cricket main match
	BEGIN
		IF @SportType = 50 AND @ParentId IS NULL	-- Cricket main match
		BEGIN
			SET @TDate = CASE
							WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay
							ELSE @ToDate
						END

			IF @RoleId = 2		-- Agent
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						ELSE 'Unknown'
					END
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
					INNER JOIN @Match AS m ON m.matchid = b.matchid
				WHERE b.recommend = @CustId
					AND b.winlostdate BETWEEN @FromDate AND @TDate
					AND b.statusID NOT IN (0, 1)
			END

			IF @RoleId = 3		-- Master
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						ELSE 'Unknown'
					END
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_MRecommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
					INNER JOIN @Match AS m ON m.matchid = b.matchid
				WHERE b.mrecommend = @CustId
					AND b.winlostdate BETWEEN @FromDate AND @TDate
					AND b.statusID NOT IN (0, 1)
			END

			IF @RoleId = 4		-- Super
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						ELSE 'Unknown'
					END
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_SRecommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
					INNER JOIN @Match AS m ON m.matchid = b.matchid
				WHERE b.srecommend = @CustId
					AND b.winlostdate BETWEEN @FromDate AND @TDate
					AND b.statusID NOT IN (0, 1)
			END
		END
		ELSE
		BEGIN
			IF @RoleId = 2		-- Agent
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'		-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'		-- Virtual Sports:: sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'	-- Betradar Virtual Sports
						WHEN s.EventType = 1 AND s.ProductID = 77 THEN 'LG'		-- Virtual Sports 3
						ELSE 'Unknown'
					END
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_Recommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				WHERE b.recommend = @CustId
					AND b.winlostdate = @EventDate
					AND b.matchid = @MatchId
					AND b.statusID NOT IN (0, 1)
			END

			IF @RoleId = 3		-- Master
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'		-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'		-- Virtual Sports:: sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'	-- Betradar Virtual Sports
						WHEN s.EventType = 1 AND s.ProductID = 77 THEN 'LG'		-- Virtual Sports 3
						ELSE 'Unknown'
					END
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_MRecommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				WHERE b.mrecommend = @CustId
					AND b.winlostdate = @EventDate
					AND b.matchid = @MatchId
					AND b.statusID NOT IN (0, 1)
			END

			IF @RoleId = 4		-- Super
			BEGIN
				INSERT INTO @Tickets (
					TransId,
					Product)
				SELECT
					b.transid,
					CASE
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'		-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'		-- Virtual Sports:: sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'	-- Betradar Virtual Sports
						WHEN s.EventType = 1 AND s.ProductID = 77 THEN 'LG'		-- Virtual Sports 3
						ELSE 'Unknown'
					END
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_SRecommend)
					INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				WHERE b.srecommend = @CustId
					AND b.winlostdate = @EventDate
					AND b.matchid = @MatchId
					AND b.statusID NOT IN (0, 1)
			END
		END

		IF @LiveIndicator IS NOT NULL
			AND EXISTS (SELECT TOP(1) 1 FROM @Tickets WHERE Product = 'NG')
		BEGIN
			DELETE c
			FROM @Tickets AS c
				INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON c.TransId = b.transid
			WHERE c.Product = 'NG' AND b.liveindicator <> @LiveIndicator
		END

		INSERT INTO @Data (
			TransId,
			RefNo,
			CustId,
			Username,
			SportType,
			BetType,
			BetId,
			BetTeam,
			Hdp1,
			Hdp2,
			OddsType,
			OddsId,
			Odds,
			MOdds,
			Stake,
			Actual_Stake,
			Status,
			SettlementStatus,
			TransDate,
			WinLostDate,
			WinLost,
			AWinLost,
			MWinLost,
			SWinLost,
			PlayerComm,
			Comm,
			AComm,
			SComm,
			APositionTaking,
			MPositionTaking,
			SPositionTaking,
			TPositionTaking,
			ADiscount,
			MDiscount,
			SDiscount,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			FinalHomeScore,
			FinalAwayScore,
			HtHomeScore,
			HtAwayScore,
			Ip,
			LeagueId,
			MatchId,
			MatchCode,
			EventDate,
			HomeId,
			AwayId,
			BetStatus,
			IsNeutral,
			ShowTime,
			BetCheck,
			ComStatus,
			TransDesc,
			OddsSpread,
			Currency,
			ExtraInfo,
			BetdaqId,
			DeviceType,
			LeagueGroupId)
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.username,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.sporttype
				ELSE 0
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			CASE
				WHEN c.Product IN ('SB', 'VS', 'VS2', 'LG') THEN b.hdp2
				ELSE 0
			END AS Hdp2,
			b.oddstype,
			b.oddsid,
			b.odds,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.modds
				ELSE 0
			END AS MOdds,
			b.stake,
			b.actual_stake,
			b.status,
			0 AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.winlost - b.actual_stake AS WinLost,
			b.awinlost,
			b.mwinLost,
			b.swinlost,
			b.playercomm,
			b.comm - b.playercomm AS Comm,
			b.acomm - b.comm AS AComm,
			b.scomm - b.acomm AS SComm,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.tpositiontaking,
			b.discount AS ADiscount,
			b.adiscount AS MDiscount,
			b.sdiscount AS SDiscount,
			b.liveindicator,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.livehomescore
				ELSE 0
			END AS LiveHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.liveawayscore
				ELSE 0
			END AS LiveAwayScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.finalhomescore
				ELSE 0
			END AS FinalHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.finalawayscore
				ELSE 0
			END AS FinalAwayScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.hthomescore
				ELSE 0
			END AS HtHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.htawayscore
				ELSE 0
			END AS HtAwayScore,
			b.ip,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.leagueid
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.matchid
				ELSE 0
			END AS MatchId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN c.Product = 'SB' THEN m.globalshowtime
				WHEN c.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.eventdate
				ELSE b.winlostdate
			END AS EventDate,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.homeid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			CASE
				WHEN c.Product IN ('VS', 'VS2', 'LG') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN c.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			CASE
				WHEN c.Product IN ('SB', 'VS2', 'LG') THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			b.currencyname AS Currency,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END,
			b.DeviceType,
			l.LeagueGroupId
		FROM @Tickets AS c
			INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON b.transid = c.TransId
			LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') AND b.matchid = m.matchid
			LEFT JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
	END

	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		TransDesc		VARCHAR(300)
	)

	SELECT * FROM @Data
	ORDER BY TransId DESC

	SELECT * FROM @BettransDetail
END
GO
