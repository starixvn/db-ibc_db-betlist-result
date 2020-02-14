/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossByBettypeMatch]
	@MatchId		INT,
	@CustId			INT			= NULL,
	@Username		VARCHAR(50)	= NULL,
	@RoleId			TINYINT,
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

	-- Support Sportsbook, Number Game, Virtual Sports, Betradar Virtual Sports only
	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest) AS s
	WHERE ProductID IN (1, 3, 5, 27)
		AND BetType NOT IN (901, 902, 903, 904)
		AND (BetType = @BetType
			OR EXISTS (SELECT 1 FROM @GroupBetType AS f WHERE f.GroupTypeId = @BetType AND f.BetType = s.BetType))

	DECLARE @IsBet14	BIT = 0,
		@EventDate		DATETIME

	SELECT @EventDate = eventdate
	FROM dbo.match WITH (NOLOCK)
	WHERE matchid = @MatchId

	IF @EventDate IS NULL
	BEGIN
		SET @IsBet14 = 1

		SELECT @EventDate = eventdate
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId
	END

	IF @CustId IS NULL
	BEGIN
		SELECT @CustId = custid
		FROM dbo.Customer WITH (NOLOCK)
		WHERE username = @Username
	END

	DECLARE @Tickets TABLE (
		TransId	BIGINT,
		Product	VARCHAR(30)
	)

	IF @IsBet14 = 0		-- bettrans range
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
					ELSE 'Unknown'
				END AS Product
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_SRecommend)
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
			WHERE b.srecommend = @CustId
				AND b.winlostdate = @EventDate
				AND b.matchid = @MatchId
				AND b.statusID NOT IN (0, 1)
		END

		IF @LiveIndicator IS NOT NULL
			AND EXISTS (SELECT TOP(1) 1 FROM @Tickets WHERE Product = 'NG')
		BEGIN
			DELETE c
			FROM @Tickets AS c
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK, INDEX = PK_bettrans) ON c.TransId = b.transid
			WHERE c.Product = 'NG' AND b.liveindicator <> @LiveIndicator
		END

		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.username,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.sporttype
				ELSE 0
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			CASE
				WHEN c.Product IN ('SB', 'VS', 'VS2') THEN b.hdp2
				ELSE 0
			END AS Hdp2,
			b.oddstype,
			b.oddsid,
			b.odds,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.modds
				ELSE 0
			END AS MOdds,
			b.stake,
			b.actual_stake,
			b.status,
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
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.livehomescore
				ELSE 0
			END AS LiveHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveawayscore
				ELSE 0
			END AS LiveAwayScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalhomescore
				ELSE 0
			END AS FinalHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalawayscore
				ELSE 0
			END AS FinalAwayScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.hthomescore
				ELSE 0
			END AS HtHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.htawayscore
				ELSE 0
			END AS HtAwayScore,
			b.ip,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.leagueid
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchid
				ELSE 0
			END AS MatchId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN c.Product = 'SB' THEN m.GlobalShowTime
				WHEN c.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
				ELSE b.winlostdate
			END AS EventDate,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.homeid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			CASE
				WHEN c.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN c.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			CASE
				WHEN c.Product IN ('SB', 'VS2') THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			b.currencyname AS Currency,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.ExtraInfo, '')
				ELSE ''
			END AS ExtraInfo
		FROM @Tickets AS c
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK, INDEX = PK_bettrans) ON b.transid = c.TransId
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
		ORDER BY c.TransId DESC
	END
	ELSE	-- bettrans14 range
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
					ELSE 'Unknown'
				END
			FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_SRecommend)
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
			WHERE b.srecommend = @CustId
				AND b.winlostdate = @EventDate
				AND b.matchid = @MatchId
				AND b.statusID NOT IN (0, 1)
		END

		IF @LiveIndicator IS NOT NULL
			AND EXISTS (SELECT TOP(1) 1 FROM @Tickets WHERE Product = 'NG')
		BEGIN
			DELETE c
			FROM @Tickets AS c
				INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON c.TransId = b.transid
			WHERE c.Product = 'NG' AND b.liveindicator <> @LiveIndicator
		END

		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.username,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.sporttype
				ELSE 0
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			CASE
				WHEN c.Product IN ('SB', 'VS', 'VS2') THEN b.hdp2
				ELSE 0
			END AS Hdp2,
			b.oddstype,
			b.oddsid,
			b.odds,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.modds
				ELSE 0
			END AS MOdds,
			b.stake,
			b.actual_stake,
			b.status,
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
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.livehomescore
				ELSE 0
			END AS LiveHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveawayscore
				ELSE 0
			END AS LiveAwayScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalhomescore
				ELSE 0
			END AS FinalHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalawayscore
				ELSE 0
			END AS FinalAwayScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.hthomescore
				ELSE 0
			END AS HtHomeScore,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.htawayscore
				ELSE 0
			END AS HtAwayScore,
			b.ip,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.leagueid
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchid
				ELSE 0
			END AS MatchId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN c.Product = 'SB' THEN m.globalshowtime
				WHEN c.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
				ELSE b.winlostdate
			END AS EventDate,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.homeid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			CASE
				WHEN c.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN c.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			CASE
				WHEN c.Product IN ('SB', 'VS2') THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			b.currencyname AS Currency,
			CASE
				WHEN c.Product IN ('SB') THEN ISNULL(b.ExtraInfo, '')
				ELSE ''
			END AS ExtraInfo
		FROM @Tickets AS c
			INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON b.transid = c.TransId
			LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
		ORDER BY c.TransId DESC
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

	SELECT * FROM @BettransDetail
END
GO


GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch] TO [bodbDownlineNetView]
GO
