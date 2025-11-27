/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_Statement]
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@MoveBetsDay	DATETIME,
	@TransType		INT				= 0
AS

/*
	Created: 20220808@Kos
	Task: NAP - Statement bet list - SiteDB
	DB: DBSIG.bodb02
	
	Revisions:
		- 20220808@Kos: Scale out DBTRANS [Redmine: #175253]
		- 20220825@Razor: Support SEAL Entertainment [Redmine: #176210]
		- 20220909@Razor: Support Microgaming RNG Casino [Redmine: #175851]
		- 20221117@Razor: Support Player Tips [Redmine: #180590]
		- 20230206@Razor: Support Jili [Redmine: #182864]
		- 20230417@Razor: Remove Betfrom column [Redmine: #126137]
		- 20230526@Razor: Support YeeBet [Redmine: #186547]
		- 20230727@Razor: Support Virtual Sports 3 [Redmine: #189205]
		- 20230909@Razor: Remove GDG, Fishing World products [Redmine: #174511]
		- 20230909@Razor: Remove GD, Colossusbet products [Redmine: #179132]
		- 20231005@Kos: Support Parlay Boost [Redmine: #194992]
		- 20231020@Razor: Support show max payout [Redmine: #194491]
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20231122@Kos: Hotfix - Can not view Yeebet ticket [Redmine: #197311]
		- 20231129@Razor: Support WE Live Casino [Redmine: #195887]
		- 20231215@Razor: Support Live22 [Redmine: #197609]
		- 20240118@Razor: HF of SEAL Entertainment [Redmine: #199994]
		- 20240222@Razor: Support Vitual Sports 4 [Redmine: #198619]
		- 20240327@Kos: Support UU Slots [Redmine: #192600]
		- 20240411@Razor: Return TranId3rd for Running ticket of Virtual Games/SportsLottery [Redmine: #203734]
		- 20240417@Razor: Support Saba xD [Redmine: #203371]
		- 20240419@Razor: Support Saba Coins [Redmine: #204003]
		- 20240626@Razor: Support FastSpin [Redmine: #205742]
		- 20240912@Razor: Support ON Casino [Redmine: #210026]
		- 20240920@Razor: Support VS2 Racing sports [Redmine: #211092]
		- 20241106@Razor: Support VS 5 - Virtually Sports [Redmine: #207589]
		- 20241210@Razor: Support VS6 - Betby Virtual Sports [Redmine: #212546]
		- 20250116@Razor: Support Direct Member [Redmine: #211969]
		- 20250428@Dave: change datatype for ExchangeID [RedmineID: #225676]
		- 20250730@Benji: Support Playtech RNG Jackpot - Support Automate Integration for Jackpot Betlist [Redmine: #234576]
		- 20250819@Razor: Support VS 2 - VS Tournament [Redmine: #235084]
		- 20250820@Benji: Support Playtech Live Jackpot[Redmine: #230127]
		- 20251027@Bobby: Support BetBuilder Hybrid Parlay [Redmine: #242255]
		- 20251114@Virgil: Hotfix - VS6 missing [Live] text [Redmine: #244025]

	Param's Explanation:
		+ @TransType:
			1: Betting Statement
			2: Void/Cancelled Bet
			3: Outstanding Bet
			4: Grand Prize (Colossus Bet)
*/

BEGIN
	SET NOCOUNT ON;

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500), RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype(ProductID, Bettype, EventType, SubProduct, RefTable)
	SELECT ProductID, BetType, EventType, SubProduct, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE Bettype NOT IN (904, 914)
		AND ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 24, 26, 30, 31, 33)
		AND (ProductID <> 6 OR SubProduct <> '')

	DECLARE @tmpStatus TABLE ([statusID] TINYINT);

	IF @TransType = 1
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 101 UNION ALL
		SELECT 102
	END
	ELSE IF @TransType = 3
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 0 UNION ALL
		SELECT 1
	END
	ELSE IF @TransType = 4	-- Grand Prize of ONERnG Jackpot
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113

		DELETE @SportBettype
		WHERE ProductID NOT IN (6)
	END

	DECLARE @Data TABLE (
		SportType			INT,
		LeagueId			INT,
		HomeId				INT,
		AwayId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		VirtualRate			FLOAT,			-- in case OpenToe, it's currency2's exchange rate 
		IsShowOTExRate		BIT,			-- Show OpenTote currency2's exchange rate or not 
		SDiscount			DECIMAL(9, 8),
		ADiscount			DECIMAL(9, 8),
		Discount			DECIMAL(9, 8),
		SettleTime			DATETIME,
		MatchId				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				BIGINT,
		TransDate			DATETIME,
		OddsId				INT,
		BetType				SMALLINT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		MOdds				MONEY,
		FinalOdds			MONEY,
		FinalOdds2			MONEY,
		OddsType			INT,
		BetTeam				NVARCHAR(50),
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		BetStatus			NVARCHAR(50),
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		Commission			MONEY,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		LiveIndicator		BIT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		HtHomeScore			INT,
		HtAwayScore			INT,
		Creator				VARCHAR(50),
		Ip					VARCHAR(45),
		Username			VARCHAR(50),
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		SPositionTaking2	SMALLMONEY,
		MPositionTaking2	SMALLMONEY,
		APositionTaking2	SMALLMONEY,
		SComm				MONEY,
		AComm				MONEY,
		Comm				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		OriginalBetType		INT,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		WalletType			TINYINT,
		RefCode				BIGINT,
		CurrencyId			SMALLINT,
		SiteId				VARCHAR(20),
		DeviceType			TINYINT
	);

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @TransType <> 4
		BEGIN
			/* normal tickets
				- Sportsbook		: ProductID = 1
				- Number Game		: ProductID = 3
				- Virtual Sports	: ProductID = 5
				- Cash Out			: ProductID = 25
			*/
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				m14.sporttype,
				m14.leagueid,
				m14.homeid,
				m14.awayid,
				m14.matchcode,
				'' AS race,
				CASE
					WHEN s.ProductID IN (1, 25) THEN m14.GlobalShowTime
					ELSE m14.eventdate
				END AS EventDate,
				0,
				0,
				b14.sdiscount,
				CASE
					WHEN b14.mrecommend = -4 THEN 0
					ELSE b14.adiscount
				END,
				CASE
					WHEN b14.recommend IN (-3, -4) THEN 0
					ELSE b14.discount
				END,
				ISNULL(b14.checktime, '') AS settletime,
				m14.matchid,
				b14.transid,
				ISNULL(b14.BetID, 0),
				b14.refno,
				b14.transdate,
				b14.oddsid,
				b14.bettype,
				b14.hdp1,
				b14.hdp2,
				b14.odds,
				b14.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b14.oddstype,
				b14.betteam,
				b14.status,
				0 AS SettlementStatus,
				m14.betstatus,
				CASE WHEN b14.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b14.stake,
				b14.actual_stake,
				(b14.winlost - b14.actual_stake) AS WinLost,
				b14.playercomm,
				b14.livehomescore,
				b14.liveawayscore,
				b14.liveindicator,
				m14.finalhomescore,
				m14.finalawayscore,
				m14.hthomescore,
				m14.htawayscore,
				b14.creator,
				b14.ip,
				b14.Username,
				ISNULL(m14.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				CASE
					WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m14.kickofftime)
					ELSE m14.showtime
				END AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b14.awinlost,
				b14.mwinlost,
				b14.swinlost,
				b14.winlostdate,
				b14.betcheck,
				ISNULL(b14.transdesc, '') AS transdesc,
				ISNULL(b14.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b14.betdaqid, -1)
					ELSE -1
				END AS BetdaqId,
				ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b14.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b14.RefCode, 0)
					ELSE 0
				END AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b14.DeviceType
			FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b14.bettype
				INNER JOIN dbo.match14 AS m14 WITH (NOLOCK) ON b14.matchid = m14.matchid
			WHERE b14.custid = @CustId
				AND b14.winlostdate = @FromDate
				AND s.EventType = 1
				AND b14.statusID IN (SELECT statusID FROM @tmpStatus)

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports), Mix Parlay (VS4), Mix Parlay (VS5)
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				0,
				0,
				0,
				0,
				'',
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b14.sdiscount,
				CASE
					WHEN b14.mrecommend = -4 THEN 0
					ELSE b14.adiscount
				END,
				CASE
					WHEN b14.recommend IN (-3, -4) THEN 0
					ELSE b14.discount
				END,
				ISNULL(b14.checktime, '') AS settletime,
				0 AS MatchId,
				b14.transid,
				ISNULL(b14.betid, 0),
				b14.refno,
				b14.transdate,
				0,
				b14.bettype,
				b14.hdp1,
				b14.hdp2,
				b14.odds,
				b14.modds,
				0 AS finalodds,
				0 AS finalodds2,
				'' AS oddstype,
				b14.betteam,
				b14.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b14.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b14.stake,
				b14.actual_stake,
				(b14.winlost - b14.actual_stake) AS WinLost,
				b14.playercomm,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				b14.creator,
				b14.ip,
				b14.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b14.awinlost,
				b14.mwinlost,
				b14.swinlost,
				b14.winlostdate,
				ISNULL(b14.betcheck, '') AS BetCheck,
				IIF(b14.bettype = 29 AND b14.OddsSpread = 3, ISNULL(b14.transdesc, ''), '') AS transdesc,
				ISNULL(b14.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b14.DeviceType
			FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
			WHERE b14.custid = @CustId
				AND b14.winlostdate = @FromDate
				AND b14.bettype IN (9, 29, 2798, 2799, 10449, 11099)
				AND b14.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Outright
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				l14.sporttype,
				o14.leagueid,
				o14.teamid,
				0,
				o14.matchcode,
				o14.groupmatch AS race,
				o14.eventdate,
				b14.virtualrate,
				CASE WHEN b14.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
				b14.sdiscount,
				CASE
					WHEN b14.mrecommend = -4 THEN 0
					ELSE b14.adiscount
				END,
				CASE
					WHEN b14.recommend IN (-3, -4) THEN 0
					ELSE b14.discount
				END,
				ISNULL(b14.checktime, '') AS settletime,
				'',
				b14.transid,
				ISNULL(b14.betid, 0),
				b14.refno,
				b14.transdate,
				o14.orid,
				b14.bettype,
				b14.hdp1,
				b14.hdp2,
				b14.odds,
				b14.modds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				b14.oddstype AS oddstype,
				'',
				b14.status,
				0 AS SettlementStatus,
				'',
				CASE WHEN b14.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b14.stake,
				b14.actual_stake,
				(b14.winlost - b14.actual_stake) AS WinLost,
				b14.playercomm,
				b14.livehomescore,
				b14.liveawayscore,
				0,
				0,
				0,
				0,
				0,
				b14.creator,
				b14.ip,
				b14.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b14.awinlost,
				b14.mwinlost,
				b14.swinlost,
				b14.winlostdate,
				b14.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b14.DeviceType
			FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS o14 WITH (NOLOCK) ON b14.matchid = o14.orid
				INNER JOIN dbo.league AS l14 WITH (NOLOCK) ON o14.leagueid = l14.leagueid
			WHERE b14.custid = @CustId
				AND b14.bettype = 10
				AND b14.winlostdate = @FromDate
				AND b14.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Virtual Horse Racing, VS2 Racing
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				r14.SportType,
				r14.LeagueID,
				0 AS homeid,
				0 AS awayid,
				'0' AS matchcode,
				b14.oddsid AS Race,
				'' AS EventDate,
				0,
				0,
				b14.sdiscount,
				CASE
					WHEN b14.mrecommend = -4 THEN 0
					ELSE b14.adiscount
				END,
				CASE
					WHEN b14.recommend IN (-3, -4) THEN 0
					ELSE b14.discount
				END,
				ISNULL(b14.checktime, '') AS settletime,
				b14.matchid,
				b14.transid,
				ISNULL(b14.BetID, 0),
				b14.refno,
				b14.transdate,
				b14.oddsid,
				b14.bettype,
				b14.hdp1,
				b14.hdp2,
				b14.odds,
				b14.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b14.oddstype,
				b14.betteam AS betteam,
				b14.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b14.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b14.stake,
				b14.actual_stake,
				(b14.winlost - b14.actual_stake) AS WinLost,
				b14.playercomm,
				b14.livehomescore,
				b14.liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b14.creator,
				b14.ip,
				b14.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b14.awinlost,
				b14.mwinlost,
				b14.swinlost,
				b14.winlostdate,
				b14.BetCheck,
				b14.transdesc AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b14.DeviceType
			FROM dbo.bettrans14 AS b14 WITH (NOLOCK)				
				INNER JOIN dbo.VSRaceInfo14 AS r14 WITH (NOLOCK) ON r14.EventID = b14.matchid
				INNER JOIN @SportBettype AS s ON s.Bettype = b14.bettype
			WHERE b14.custid = @CustId
				AND b14.winlostdate = @FromDate
				AND s.EventType = 3
				AND b14.statusID IN (SELECT statusID FROM @tmpStatus)

			-- RNG Casino, Keno, AG Casino, AllBet, Voidbridge, NG2, Lottery, Pragmatic Casino
			-- Card Club, NPH Promotion, Spadegaming, Virtual Games, SA Gaming, Indo 4D, Sexy Gaming, Saba.club, Table Game, BBIN
			-- IBCBet Live Casino, RNG War, ION, PG Soft, Joker, WM, Leap Gaming Virtual Sports, Big Gaming, Happy 5 Linked Games (Number Game)
			-- MaxGame, Habanero, CG, Sports Lottery, PP Live Casino, VGaming, AdvantPlay, AdvantPlay Mini, FGG, SEAL, MG RNGCasino, Player Tips, Jili, YeeBet, WE, Live22, UU Slots
			-- Saba xD, Saba coins
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				CASE
					WHEN s.ProductID = 6 THEN b14.matchid
					WHEN s.ProductID = 8 THEN 202
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 21 THEN 211
					WHEN s.ProductID = 22 THEN 212
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					WHEN s.ProductID = 28 THEN 220
					WHEN s.ProductID = 32 THEN 248
					WHEN s.ProductID IN (3, 34, 36, 37, 38, 39, 40, 42, 43, 45, 46, 47, 49, 50, 51, 52, 55, 56, 57, 60, 61, 62, 63, 65, 66, 67, 68, 70, 72, 73, 74, 75, 76, 78, 80, 79, 86, 81) THEN b14.matchid
					WHEN s.RefTable IN (1, 2) THEN b14.matchid
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b14.sdiscount,
				CASE
					WHEN b14.mrecommend = -4 THEN 0
					ELSE b14.adiscount
				END,
				CASE
					WHEN b14.recommend IN (-3, -4) THEN 0
					ELSE b14.discount
				END,
				ISNULL(b14.checktime, '') AS settletime,
				CASE
					WHEN s.ProductId = 23 THEN b14.betdaqid
					WHEN s.ProductId = 74 THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
					ELSE 0
				END AS MatchID,
				b14.transid,
				ISNULL(b14.betid, 0),
				b14.refno,
				b14.transdate,
				b14.oddsid,
				b14.bettype,
				CASE
					WHEN s.ProductId = 23 THEN b14.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN s.ProductId = 23 THEN b14.hdp2
					ELSE 0
				END AS hdp2,
				CASE 
					WHEN s.ProductID IN (3, 6, 8, 23, 28, 32, 36, 38, 40, 42, 43, 49, 63, 66) THEN b14.Odds
					ELSE 0 
				END AS Odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				'' AS betteam,
				CASE
					WHEN s.ProductID = 40 AND b14.status = 'Won' AND b14.modds = 0.25 THEN 'Half Won'
					WHEN s.ProductID = 40 AND b14.status = 'Lose' AND b14.modds = -0.25 THEN 'Half Lose'
					ELSE b14.status
				END AS status,
				0 AS SettlementStatus,
				'' AS betstatus,
				'' AS comstatus,
				b14.stake,
				b14.actual_stake,
				(b14.winlost - b14.actual_stake) AS WinLost,
				b14.playercomm,
				CASE
					WHEN s.ProductId = 23 THEN b14.livehomescore
					ELSE 0
				END AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b14.creator,
				b14.ip,
				b14.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS spositiontaking, -- unuse in this report
				0 AS mpositiontaking, -- unuse in this report
				0 AS apositiontaking, -- unuse in this report
				0 AS spositiontaking2,-- unuse in this report
				0 AS mpositiontaking2,-- unuse in this report
				0 AS apositiontaking2,-- unuse in this report
				0 AS scomm, -- unuse in this report
				0 AS acomm, -- unuse in this report
				0 AS comm,	-- unuse in this report
				b14.awinlost,
				b14.mwinlost,
				b14.swinlost,
				b14.winlostdate,
				CASE
					WHEN s.ProductID IN (3, 38, 63) THEN b14.betcheck
					WHEN s.ProductId = 8 THEN ISNULL(b14.comstatus, '')
					ELSE ''
				END AS betcheck,
				CASE
					WHEN s.ProductId IN (3, 6, 8, 22, 23, 28, 32, 34, 36, 38, 40, 43, 49, 55, 56, 61, 62, 63, 67, 68, 72) THEN b14.transdesc
					ELSE ''
				END AS transdesc,
				CASE
					WHEN s.SubProduct LIKE 'Jackpot%' THEN ISNULL(b14.oddsspread, 0)
					ELSE 0
				END AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				CASE
					WHEN s.ProductId IN (3, 63) THEN b14.currency
					ELSE 0
				END AS CurrencyId,
				CASE
					WHEN s.ProductID IN (3, 38, 63) THEN CONVERT(VARCHAR(20), b14.betdaqid)
					ELSE ''
				END AS SiteId,
				b14.DeviceType
			FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b14.bettype
			WHERE b14.custid = @CustId
				AND b14.winlostdate = @FromDate
				AND (s.ProductID IN (6, 8, 11, 21, 22, 23, 28, 32, 34, 36, 37, 38, 39, 40, 42, 43, 45, 46, 47, 49, 50, 51, 52, 55, 56, 57, 60, 61, 62, 63, 65, 66, 67, 68, 70, 72, 73, 74, 75, 76, 78, 80, 79, 86, 81)
						OR (s.ProductID = 3 AND s.EventType = 0)
						OR s.RefTable IN (1, 2))
				AND b14.statusID IN (SELECT [statusID] FROM @tmpStatus)
			
			-- Bitcoin, VS 5, VS 6
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				m14.sporttype,
				CASE
					WHEN s.ProductID = 69 THEN 0 
					ELSE m14.League3rdId
				END AS leagueid,
				CASE 
					WHEN s.ProductID = 69 THEN 0 
					ELSE m14.HomeId
				END AS homeid,
				CASE
					WHEN s.ProductID = 69 THEN 0
					ELSE m14.AwayId
				END AS awayid,
				CASE 
					WHEN s.ProductId = 88 THEN m14.matchcode
					ELSE ''
				END AS matchcode,
				'' AS race,
				m14.EndTime AS EventDate,
				0,
				0,
				b14.sdiscount,
				CASE
					WHEN b14.mrecommend = -4 THEN 0
					ELSE b14.adiscount
				END,
				CASE
					WHEN b14.recommend IN (-3, -4) THEN 0
					ELSE b14.discount
				END,
				'' AS settletime,
				b14.matchid,
				b14.transid,
				CASE
					WHEN s.ProductId = 71 THEN b14.BetID
					ELSE 0 
				END AS BetId,
				b14.refno,
				b14.transdate,
				0 AS oddsid,
				b14.bettype,
				b14.hdp1,
				CASE 
					WHEN s.ProductID = 69 THEN 0
					ELSE b14.hdp2
				END AS hdp2,
				b14.odds,
				CASE 
					WHEN s.ProductId = 88 THEN b14.modds
					ELSE 0
				END AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				b14.oddstype,
				b14.betteam,
				b14.status,
				0 AS SettlementStatus,
				m14.betstatus,
				0 AS comstatus,
				b14.stake,
				b14.actual_stake,
				(b14.winlost - b14.actual_stake) AS WinLost,
				b14.playercomm,
				CASE 
					WHEN s.ProductId = 88 THEN b14.livehomescore
					ELSE 0
				END AS livehomescore,
				CASE 
					WHEN s.ProductId = 88 THEN b14.liveawayscore
					ELSE 0
				END AS liveawayscore,
				CASE 
					WHEN s.ProductId IN (71, 88) THEN b14.liveindicator
					ELSE 0
				END AS liveindicator,
				CASE 
					WHEN s.ProductId = 88 THEN m14.finalhomescore
					ELSE 0
				END AS finalhomescore,
				CASE 
					WHEN s.ProductId = 88 THEN m14.finalawayscore
					ELSE 0
				END AS finalawayscore,
				0 hthomescore,
				0 htawayscore,
				b14.creator,
				b14.ip,
				b14.Username,
				0 AS IsNeutral,
				CASE 
					WHEN s.ProductID = 71 THEN CONVERT(NVARCHAR(50), m14.StartTime)
					ELSE '' 
				END AS ShowTime,
				b14.spositiontaking,
				b14.mpositiontaking,
				b14.apositiontaking,
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,
				(b14.scomm - b14.acomm) AS scomm,
				(b14.acomm - b14.comm) AS acomm,
				(b14.comm - b14.playercomm) AS comm,	
				b14.awinlost,
				b14.mwinlost,
				b14.swinlost,
				b14.winlostdate,
				CASE 
					WHEN s.ProductId = 88 THEN b14.betcheck
					ELSE 0
				END AS betcheck,
				CASE 
					WHEN s.ProductId = 88 THEN b14.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				b14.ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b14.DeviceType
			FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b14.bettype
				INNER JOIN dbo.match3rd14 AS m14 WITH (NOLOCK) ON b14.matchid = m14.match3rdid
			WHERE b14.custid = @CustId
				AND b14.winlostdate = @FromDate
				AND b14.statusID IN (SELECT statusID FROM @tmpStatus);

			-- Get match info for Player Tips
			IF EXISTS (SELECT 1 FROM @Data WHERE SportType = 157)
			BEGIN
				UPDATE b14
				SET
					LeagueId = m14.leagueid,
					HomeId = m14.homeid,
					AwayId = m14.awayid,
					EventDate = m14.GlobalShowTime
				FROM @Data AS b14
					INNER JOIN dbo.match14 AS m14 WITH (NOLOCK) ON m14.matchid = b14.MatchId
				WHERE b14.SportType = 157
			END
		END
	END
	ELSE
	BEGIN
		IF @TransType <> 4
		BEGIN
			/* normal tickets
				- Sportsbook		: ProductID = 1
				- Number Game		: ProductID = 3
				- Virtual Sports	: ProductID = 5
				- Cash Out			: ProductID = 25
			*/
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				m.sporttype,
				m.leagueid,
				m.homeid,
				m.awayid,
				m.matchcode,
				'' AS race,
				CASE
					WHEN s.ProductID IN (1, 25) THEN m.GlobalShowTime
					ELSE m.eventdate
				END AS EventDate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				ISNULL(b.checktime, '') AS settletime,
				m.matchid,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b.oddstype,
				b.betteam,
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				m.betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				m.finalhomescore,
				m.finalawayscore,
				m.hthomescore,
				m.htawayscore,
				b.creator,
				b.ip,
				b.Username,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral, --phuong.nguyen, get isneutral from Match
				CASE
					WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE m.showtime
				END AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.BetCheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
					ELSE -1
				END AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
				ELSE 0
			END AS RefCode,
			0 AS CurrencyId,
			'' AS SiteId,
			b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.EventType = 1
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND (b.bettype NOT BETWEEN 801 AND 806			--exclude metric gaming running ticket
					OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))

			-- Metric gaming running ticket
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT 
				m.sporttype,
				m.leagueid,
				m.homeid,
				m.awayid,
				m.matchcode,
				'' AS race,
				m.GlobalShowTime AS EventDate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				'' AS settletime,
				m.matchid,
				b.translogid AS transid,
				0 AS BetID,
				b.translogid AS refno,
				b.transdate,
				0 AS oddsid,
				b.gameID AS bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				CASE
					WHEN b.gameid IN (801, 803, 804, 805, 806) THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS OddsType,
				'' AS betteam,
				b.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				m.betstatus,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				0 AS WinLost,
				0 AS playercomm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				m.finalhomescore,
				m.finalawayscore,
				m.hthomescore,
				m.htawayscore,
				b.creator,
				b.ip,
				b.Username,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral, --phuong.nguyen, get isneutral from Match
				m.showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				b.winlostdate,
				'' AS BetCheck,
				b.transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM
				dbo.translog AS b WITH (NOLOCK)
				INNER JOIN CustDB.dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND b.gameID BETWEEN 801 AND 899
				AND b.statusID IN (0,1)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus WHERE statusID IN (0, 1))

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports), Mix Parlay (VS4), Mix Parlay (VS5)
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT 
				0,
				0,
				0,
				0,
				'',
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				ISNULL(b.checktime, '') AS settletime,
				0 AS MatchId,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				0,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				'' AS oddstype,
				b.betteam,
				CASE
					WHEN b.status = 'running' THEN
						CASE
							WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
										WHERE bm.custid = b.custid
											AND bm.refno = b.refno
											AND (bm.status = 'waiting'
												OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
								THEN 'Waiting'
							ELSE b.status
						END
					ELSE b.status
				END AS Status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				ISNULL(b.betcheck, '') AS BetCheck,
				IIF(b.bettype = 29 AND b.OddsSpread = 3, ISNULL(b.transdesc, ''), '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND b.bettype IN (9, 29, 2798, 2799, 10449, 11099)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Outright
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT 
				l.sporttype,
				o.leagueid,
				o.teamid,
				0,
				o.matchcode,
				o.groupmatch AS race,
				o.eventdate,
				b.virtualrate,
				CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				'' AS settletime,
				'',
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				o.orid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				b.oddstype AS oddstype,
				'',
				b.status,
				0 AS SettlementStatus,
				'',
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0,
				0,
				0,
				0,
				0,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE b.custid = @CustId
				AND b.bettype = 10
				AND b.winlostdate = @FromDate
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Virtual Horse Racing, VS2 Racing
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT 
				r.SportType,
				r.LeagueID,
				0 AS homeid,
				0 AS awayid,
				'0' AS matchcode,
				b.oddsid AS Race,
				'' AS EventDate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				ISNULL(b.checktime, '') AS settletime,
				b.matchid,
				b.transid,
				ISNULL(b.BetID, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b.oddstype,
				b.betteam AS betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.BetCheck,
				b.transdesc AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = b.matchid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.EventType = 3
				AND b.statusID IN (SELECT statusID FROM @tmpStatus)

			-- NG2, BBIN
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				CASE
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					WHEN s.ProductID IN (47) THEN b.matchid
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				'' AS settletime,
				CASE
					WHEN s.ProductId = 23 THEN b.betdaqid
					ELSE 0
				END AS matchid,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp2
					ELSE 0
				END AS hdp2,
				b.odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS oddstype,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				CASE
					WHEN s.ProductId = 23 THEN b.livehomescore
					ELSE 0
				END AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0, --finalhomescore, 
				0, --finalawayscore, 
				0, --hthomescore, 
				0, --htawayscore,
				b.creator,
				b.ip,
				b.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS spositiontaking, -- unuse in this report
				0 AS mpositiontaking, -- unuse in this report
				0 AS apositiontaking, -- unuse in this report
				0 AS spositiontaking2,-- unuse in this report
				0 AS mpositiontaking2,-- unuse in this report
				0 AS apositiontaking2,-- unuse in this report
				0 AS scomm, -- unuse in this report
				0 AS acomm, -- unuse in this report
				0 AS comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				'' AS BetCheck,
				CASE
					WHEN s.ProductId = 23 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductId IN (23, 47)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus);

			-- Keno, Lottery, Virtual Games, Table Games, Indo 4D, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery (translog)
			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE statusID IN (0, 1))
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
					, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
					, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
					, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
					, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
					, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT 
					CASE
						WHEN s.ProductId = 8 THEN 202
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 38, 40, 43, 49, 63) THEN b.productID
						ELSE 0
					END AS sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					b.sdiscount,
					CASE
						WHEN b.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					'' AS settletime,
					0 AS MatchId,
					0 AS transid,
					0 AS betid,
					b.translogid AS refno,
					b.transdate,
					0 AS oddsid,
					b.gameID AS bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductId IN (3, 8, 28, 38, 40, 43, 49, 63) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					'' AS betteam,
					b.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					0 AS comstatus,
					b.stake,
					b.actual_stake,
					0 AS WinLost,
					0 AS playercomm,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					b.winlostdate,
					CASE
						WHEN s.ProductId IN (3) THEN b.GameID3rd
						WHEN s.ProductId IN (38, 63) THEN b.TranId3rd
						WHEN s.ProductId = 8 THEN ISNULL(b.custom2, '')
						WHEN s.ProductId = 49 THEN ISNULL(b.custom1, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductId IN (3, 8, 28, 38, 40, 43, 49, 63) THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					CASE
						WHEN s.ProductId IN (3, 63) THEN b.currency
						ELSE 0
					END AS CurrencyId,
					CASE
						WHEN s.ProductId IN (3, 38, 63) THEN b.SiteId
						ELSE ''
					END AS SiteId,
					b.DeviceType
				FROM dbo.translog AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.custid = @CustId
					AND b.winlostdate = @FromDate
					AND (s.ProductID IN (8, 28, 38, 40, 43, 49, 63)
							OR (s.ProductID = 3 AND s.EventType = 0))
					AND b.statusID IN (0, 1)
			END

			-- Keno, Lottery, NPH Promotion, Virtual Games, Table Games, Indo 4D, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery, Player Tips, Saba Coin (bettrans)
			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE statusID NOT IN (0, 1))
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
					, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
					, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
					, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
					, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
					, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductId = 8 THEN 202
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 37, 38, 40, 43, 49, 63, 74, 81) THEN bkn.matchid
						ELSE 0
					END AS sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					bkn.sdiscount,
					CASE
						WHEN bkn.mrecommend = -4 THEN 0
						ELSE bkn.adiscount
					END,
					CASE
						WHEN bkn.recommend IN (-3, -4) THEN 0
						ELSE bkn.discount
					END,
					'' AS settletime,
					CASE
						WHEN s.ProductId = 74 THEN ISNULL(CAST(('<xml>' + bkn.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
						ELSE 0
					END AS matchid,
					bkn.transid,
					ISNULL(bkn.BetID, 0) AS betid,
					bkn.refno,
					bkn.transdate,
					0 AS oddsid,
					bkn.bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductId IN (3, 8, 28, 38, 40, 43, 49, 63) THEN bkn.odds
						ELSE 0
					END AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					'' AS betteam,
					CASE
						WHEN s.ProductID = 40 AND bkn.status = 'Won' AND bkn.modds = 0.25 THEN 'Half Won'
						WHEN s.ProductID = 40 AND bkn.status = 'Lose' AND bkn.modds = -0.25 THEN 'Half Lose'
						ELSE bkn.status
					END AS status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN bkn.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bkn.stake,
					bkn.actual_stake,
					(bkn.winlost - bkn.actual_stake) AS WinLost,
					bkn.playercomm,
					bkn.livehomescore,
					bkn.liveawayscore,
					bkn.liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					bkn.creator,
					bkn.ip,
					bkn.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					bkn.awinlost,
					bkn.mwinlost,
					bkn.swinlost,
					bkn.winlostdate,
					CASE
						WHEN s.ProductId IN (3, 28, 38, 63) THEN bkn.betcheck
						WHEN s.ProductId = 8 THEN ISNULL(bkn.comstatus, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductId IN (3, 8, 28, 38, 40, 43, 49, 63) THEN bkn.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(bkn.ExtraInfo, '') AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					CASE
						WHEN s.ProductId IN (3, 63) THEN bkn.currency
						ELSE 0
					END AS CurrencyId,
					CASE
						WHEN s.ProductId IN (3, 38, 63) THEN CONVERT(VARCHAR(20), bkn.betdaqid)
						ELSE ''
					END AS SiteId,
					bkn.DeviceType
					FROM dbo.bettrans AS bkn WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = bkn.bettype
					WHERE  bkn.custid = @CustId
						AND bkn.winlostdate = @FromDate
						AND (s.ProductID IN (8, 28, 37, 38, 40, 43, 49, 63, 74, 81)
								OR (s.ProductID = 3 AND s.EventType = 0))
						AND bkn.statusID IN (SELECT [statusID] FROM @tmpStatus)

				-- Get match info for Player Tips
				IF EXISTS (SELECT 1 FROM @Data WHERE SportType = 157)
				BEGIN
					UPDATE b
					SET
						LeagueId = m.leagueid,
						HomeId = m.homeid,
						AwayId = m.awayid,
						EventDate = m.GlobalShowTime
					FROM @Data AS b
						INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
					WHERE b.SportType = 157
				END
			END

			-- RNG Casino Single Wallet, Voidbridge, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, Habanero, CG, VGaming
			-- AdvantPlay, AdvantPlay Mini, SEAL, MG RNGCasino, Jili, Live22, UU Slots, Saba xD
			IF @TransType = 1	-- before yesterday settled ticket
				AND @FromDate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
					, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
					, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
					, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
					, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
					, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 32 THEN 248
						ELSE br1.matchid
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					br1.sdiscount,
					CASE
						WHEN br1.mrecommend = -4 THEN 0
						ELSE br1.adiscount
					END,
					CASE
						WHEN br1.recommend IN (-3, -4) THEN 0
						ELSE br1.discount
					END,
					'' AS settletime,
					0 AS matchid,
					br1.transid,
					ISNULL(br1.betid, 0) AS betid,
					br1.refno,
					br1.transdate,
					0 AS oddsid,
					br1.bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%' THEN br1.odds
						ELSE 0
					END AS Odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					br1.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN br1.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					br1.stake,
					br1.actual_stake,
					(br1.winlost - br1.actual_stake) AS WinLost,
					br1.playercomm AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					br1.creator,
					br1.ip,
					br1.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					br1.awinlost,
					br1.mwinlost,
					br1.swinlost,
					br1.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN br1.transdesc
						ELSE ''
					END AS transdesc,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%' THEN ISNULL(br1.oddsspread, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					br1.DeviceType
				FROM dbo.bettrans AS br1 WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = br1.bettype
				WHERE br1.custid = @CustId
					AND br1.winlostdate = @FromDate
					AND (s.ProductId IN (6, 22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR s.RefTable = 1)
					AND br1.statusID IN (SELECT [statusID] FROM @tmpStatus)
			END

			IF @TransType = 1	-- yesterday and today settled ticket
				AND @FromDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
					, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
					, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
					, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
					, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
					, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 32 THEN 248
						ELSE br1.matchid
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(brng.sdiscount) AS sdiscount,
					CASE
						WHEN brng.mrecommend = -4 THEN 0
						ELSE AVG(brng.adiscount) 
					END AS adiscount,
					CASE
						WHEN brng.recommend IN (-3, -4) THEN 0
						ELSE AVG(brng.discount) 
					END AS discount,
					'' AS settletime,
					0 AS matchid,
					br1.transid,
					ISNULL(br1.betid, 0) AS betid,
					br1.refno,
					br1.transdate,
					0 AS oddsid,
					br1.bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%'
							THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					CASE 
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN br1.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(brng.stake) AS stake,
					SUM(brng.actual_stake) AS actual_stake,
					SUM(brng.winlost - brng.actual_stake) AS WinLost,
					SUM(brng.playercomm) AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,	
					0 AS htawayscore,
					br1.creator,
					br1.ip,
					br1.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					SUM(brng.awinlost) AS awinlost,
					SUM(brng.mwinlost) AS mwinlost,
					SUM(brng.swinlost) AS swinlost,
					br1.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN br1.transdesc
						ELSE ''
					END AS transdesc,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%' THEN ISNULL(SUM(brng.BetStake), 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					br1.DeviceType
				FROM dbo.bettrans AS br1 WITH (NOLOCK)
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = br1.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = br1.bettype
				WHERE br1.custid = @CustId
					AND br1.winlostdate = @FromDate
					AND (s.ProductId IN (6, 22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR s.RefTable = 1)
					AND brng.statusID NOT IN (0, 1)
				GROUP BY
					br1.transid,
					s.SubProduct,
					ISNULL(br1.betid, 0),
					br1.bettype,
					br1.refno,
					br1.transdate,
					br1.winlostdate,
					br1.custid,
					br1.creator,
					br1.ip,
					br1.Username,
					br1.comstatus,
					br1.matchid,
					br1.transdesc,
					s.ProductID,
					br1.DeviceType,
					brng.recommend,
					brng.mrecommend
				OPTION (RECOMPILE)
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE [statusID] IN (0, 1))	-- yesterday and later running ticket
				AND @FromDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
					, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
					, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
					, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
					, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
					, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 32 THEN 248
						ELSE bry.matchid
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(brng.sdiscount) AS sdiscount,
					CASE
						WHEN brng.mrecommend = -4 THEN 0
						ELSE AVG(brng.adiscount) 
					END AS adiscount,
					CASE
						WHEN brng.recommend IN (-3, -4) THEN 0
						ELSE AVG(brng.discount) 
					END AS discount,
					'' AS settletime,
					0 AS matchid,
					bry.transid,
					ISNULL(bry.betid, 0) AS betid,
					bry.refno,
					bry.transdate,
					0 AS oddsid,
					bry.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					'Running' AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN bry.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(brng.stake) AS stake,
					SUM(brng.actual_stake) AS actual_stake,
					0 AS WinLost,
					0 AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					bry.creator,
					bry.ip,
					bry.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					bry.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN bry.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					bry.DeviceType
				FROM dbo.bettrans AS bry WITH (NOLOCK)
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = bry.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = bry.bettype
				WHERE bry.custid = @CustId
					AND bry.winlostdate = @FromDate
					AND (s.ProductId IN (6, 22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR s.RefTable = 1)
					AND brng.statusID IN (0, 1)
				GROUP BY
					bry.transid,
					ISNULL(bry.betid, 0),
					bry.Bettype,
					bry.refno,
					bry.transdate,
					bry.winlostdate,
					bry.custid,
					bry.creator,
					bry.ip,
					bry.Username,
					bry.comstatus,
					bry.matchid,
					bry.transdesc,
					s.ProductID,
					bry.DeviceType,
					brng.recommend,
					brng.mrecommend
				OPTION (RECOMPILE)
			END

			-- AG Casino, AllBet, SA Gaming, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming, PP Live Casino, FGG, YeeBet, WE
			IF @TransType = 1	-- before yesterday settled ticket
				AND @FromDate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
					, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
					, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
					, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
					, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
					, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						ELSE by1.matchid
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					by1.sdiscount,
					CASE
						WHEN by1.mrecommend = -4 THEN 0
						ELSE by1.adiscount
					END,
					CASE
						WHEN by1.recommend IN (-3, -4) THEN 0
						ELSE by1.discount
					END,
					'' AS settletime,
					0 AS matchid,
					by1.transid,
					ISNULL(by1.betid, 0) AS betid,
					by1.refno,
					by1.transdate,
					0 AS oddsid,
					by1.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					by1.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN by1.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					by1.stake,
					by1.actual_stake,
					(by1.winlost - by1.actual_stake) AS WinLost,
					by1.playercomm AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					by1.creator,
					by1.ip,
					by1.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					by1.awinlost,
					by1.mwinlost,
					by1.swinlost,
					by1.winlostdate,
					'' AS BetCheck,
					'' AS transdesc,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%' THEN ISNULL(by1.oddsspread, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					by1.DeviceType
				FROM dbo.bettrans AS by1 WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = by1.bettype
				WHERE by1.custid = @CustId
					AND by1.winlostdate = @FromDate
					AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
					AND by1.statusID IN (SELECT [statusID] FROM @tmpStatus)
			END

			IF @TransType = 1	-- yesterday and today settled ticket
				AND @FromDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
					, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
					, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
					, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
					, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
					, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						ELSE byc.matchid
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(blc.sdiscount) AS sdiscount,
					CASE
						WHEN blc.mrecommend = -4 THEN 0
						ELSE AVG(blc.adiscount) 
					END AS adiscount,
					CASE
						WHEN blc.recommend IN (-3, -4) THEN 0
						ELSE AVG(blc.discount) 
					END AS discount,
					'' AS settletime,
					0 AS matchid,
					byc.transid,
					ISNULL(byc.BetID, 0) AS betid,
					byc.refno,
					byc.transdate,
					0 AS oddsid,
					byc.bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%'
							THEN ISNULL(AVG(CASE WHEN blc.statusID IN (111, 112, 113) THEN blc.ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					CASE 
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN byc.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(blc.stake) AS stake,
					SUM(blc.actual_stake) AS actual_stake,
					SUM(blc.winlost - blc.actual_stake) AS WinLost,
					SUM(blc.playercomm) AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					byc.creator,
					byc.ip,
					byc.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					SUM(blc.awinlost) AS awinlost,
					SUM(blc.mwinlost) AS mwinlost,
					SUM(blc.swinlost) AS swinlost,
					byc.winlostdate,
					'' AS BetCheck,
					'' AS transdesc,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%' THEN ISNULL(SUM(blc.BetStake), 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					byc.DeviceType
				FROM dbo.bettrans AS byc WITH (NOLOCK)
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = byc.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = byc.bettype
				WHERE byc.custid = @CustId
					AND byc.winlostdate = @FromDate
					AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
					AND blc.statusID NOT IN (0, 1)
				GROUP BY
					byc.transid,
					ISNULL(byc.betid, 0),
					byc.bettype,
					byc.refno,
					byc.transdate,
					byc.winlostdate,
					byc.custid,
					byc.creator,
					byc.ip,
					byc.Username,
					byc.comstatus,
					s.ProductID,
					byc.matchid,
					byc.DeviceType,
					blc.recommend,
					blc.mrecommend,
					s.SubProduct
				OPTION (RECOMPILE)
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE [statusID] IN (0, 1))	-- yesterday and later running ticket
				AND @FromDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
					, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
					, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
					, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
					, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
					, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						ELSE b.matchid
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(blc.sdiscount) AS sdiscount,
					CASE
						WHEN blc.mrecommend = -4 THEN 0
						ELSE AVG(blc.adiscount) 
					END AS adiscount,
					CASE
						WHEN blc.recommend IN (-3, -4) THEN 0
						ELSE AVG(blc.discount) 
					END AS discount,
					'' AS settletime,
					0 AS matchid,
					b.transid,
					ISNULL(b.betid, 0) AS betid,
					b.refno,
					b.transdate,
					0 AS oddsid,
					b.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					'Running' AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(blc.stake) AS stake,
					SUM(blc.actual_stake) AS actual_stake,
					0 AS WinLost,
					0 AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					b.creator,
					b.ip,
					b.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					b.winlostdate,
					'' AS BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					b.DeviceType
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId
					AND b.winlostdate = @FromDate
					AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
					AND blc.statusID IN (0, 1)
				GROUP BY
					b.transid,
					ISNULL(b.betid, 0),
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.custid,
					b.creator,
					b.ip,
					b.Username,
					b.comstatus,
					s.ProductID,
					b.matchid,
					b.DeviceType,
					blc.mrecommend,
					blc.recommend
				OPTION (RECOMPILE)
			END

			-- Bitcoin, VS 5, VS 6
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, SettleTime, MatchId
				, TransId, BetId, RefNo, TransDate, OddsId, BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status, SettlementStatus
				, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission, LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore
				, HtHomeScore, HtAwayScore, Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2
				, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType
				, BetdaqId, ExtraInfo, WalletType, RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				m.sporttype,
				CASE
					WHEN s.ProductID = 69 THEN 0 
					ELSE m.League3rdId
				END AS leagueid,
				CASE 
					WHEN s.ProductID = 69 THEN 0 
					ELSE m.HomeId
				END AS homeid,
				CASE
					WHEN s.ProductID = 69 THEN 0
					ELSE m.AwayId
				END AS awayid,
				CASE 
					WHEN s.ProductId = 88 THEN m.matchcode
					ELSE ''
				END AS matchcode,
				'' AS race,
				m.EndTime AS EventDate,
				0,
				0,
				bis.sdiscount,
				CASE
					WHEN bis.mrecommend = -4 THEN 0
					ELSE bis.adiscount
				END,
				CASE
					WHEN bis.recommend IN (-3, -4) THEN 0
					ELSE bis.discount
				END,
				'' AS settletime,
				bis.matchid,
				bis.transid,
				CASE
					WHEN s.ProductId = 71 THEN bis.BetID
					ELSE 0 
				END AS BetId,
				bis.refno,
				bis.transdate,
				0.oddsid,
				bis.bettype,
				bis.hdp1,
				CASE 
					WHEN s.ProductID = 69 THEN 0
					ELSE bis.hdp2
				END AS hdp2,
				bis.odds,
				CASE 
					WHEN s.ProductId = 88 THEN bis.modds
					ELSE 0
				END AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				bis.oddstype,
				bis.betteam,
				bis.status,
				0 AS SettlementStatus,
				m.betstatus,
				0 AS comstatus,
				bis.stake,
				bis.actual_stake,
				(bis.winlost - bis.actual_stake) AS WinLost,
				bis.playercomm,
				CASE 
					WHEN s.ProductId = 88 THEN bis.livehomescore
					ELSE 0
				END AS livehomescore,
				CASE 
					WHEN s.ProductId = 88 THEN bis.liveawayscore
					ELSE 0
				END AS liveawayscore,
				CASE 
					WHEN s.ProductId IN (71, 88) THEN bis.liveindicator
					ELSE 0
				END AS liveindicator,
				CASE 
					WHEN s.ProductId = 88 THEN m.finalhomescore
					ELSE 0
				END AS finalhomescore,
				CASE 
					WHEN s.ProductId = 88 THEN m.finalawayscore
					ELSE 0
				END AS finalawayscore,
				0 hthomescore,
				0 htawayscore,
				bis.creator,
				bis.ip,
				bis.Username,
				0 AS IsNeutral,
				CASE 
					WHEN s.ProductID = 71 THEN CONVERT(NVARCHAR(50), m.StartTime)
					ELSE '' 
				END AS ShowTime,
				bis.spositiontaking,
				bis.mpositiontaking,
				bis.apositiontaking,
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,
				(bis.scomm - bis.acomm) AS scomm,
				(bis.acomm - bis.comm) AS acomm,
				(bis.comm - bis.playercomm) AS comm,
				bis.awinlost,
				bis.mwinlost,
				bis.swinlost,
				bis.winlostdate,
				CASE 
					WHEN s.ProductId = 88 THEN bis.betcheck
					ELSE 0
				END AS betcheck,
				CASE 
					WHEN s.ProductId = 88 THEN bis.transdesc
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				bis.ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				bis.DeviceType
			FROM dbo.bettrans AS bis WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = bis.bettype
				INNER JOIN dbo.match3rd AS m WITH (NOLOCK) ON bis.matchid = m.match3rdid
			WHERE bis.custid = @CustId
				AND bis.winlostdate = @FromDate
				AND bis.statusID IN (SELECT statusID FROM @tmpStatus)

		END
	END

	-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
	IF EXISTS (SELECT 1 FROM @Data WHERE BetType = 29 AND BetTeam = '1')
	BEGIN
		-- Running/Waiting
		DECLARE @ParlayData TABLE (
			RefNo		BIGINT,
			BoostRate	MONEY)

		INSERT INTO @ParlayData(RefNo, BoostRate)
		SELECT
			b.refno,
			CASE
				WHEN b.bettype = 29 AND b.betteam = 1 AND b.oddsspread = 2 THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@bbp)[1]','MONEY'), 0)
				ELSE 0
			END AS BoostRate
		FROM @Data AS b
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.Status IN ('Running', 'Waiting')

		DECLARE @TmpParlayData TABLE (
			RefNo	BIGINT,
			Odds	MONEY,
			MOdds	MONEY)

		-- Mix Parlay which having at least 1 settled sub ticket
		INSERT INTO @TmpParlayData(RefNo, Odds, MOdds)
		SELECT
			b.RefNo,
			dbo.PRODUCT(bpd.odds) AS Odds,
			dbo.PRODUCT(bpd.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
		FROM @ParlayData AS b
			INNER JOIN dbo.BetParlayDetail AS bpd WITH (NOLOCK) ON bpd.RefNo = b.RefNo
		GROUP BY
			b.RefNo,
			b.BoostRate

		-- Mix Parlay which having no settled sub ticket
		INSERT INTO @TmpParlayData(RefNo, Odds, MOdds)
		SELECT
			b.RefNo,
			dbo.PRODUCT(bm.odds) AS Odds,
			dbo.PRODUCT(bm.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
		FROM @ParlayData AS b
			INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.RefNo
		WHERE NOT EXISTS (SELECT 1 FROM @TmpParlayData WHERE RefNo = b.RefNo)
		GROUP BY
			b.RefNo,
			b.BoostRate

		UPDATE b
		SET
			b.Odds = td.Odds,
			b.MOdds = td.MOdds
		FROM @Data AS b
			INNER JOIN @TmpParlayData AS td ON td.RefNo = b.RefNo

		-- Settled
		UPDATE b
		SET
			b.Odds = bpr.Odds,
			b.Modds = bpr.mOdds,
			b.TransDesc = IIF(b.OddsSpread = 3, b.TransDesc, CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, '')))
		FROM @Data AS b
			INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.Status NOT IN ('Running', 'Waiting')
	END

	UPDATE tblTemp
	SET tblTemp.Creator = cu.username
	FROM @Data AS tblTemp
		INNER JOIN CustDB.dbo.Customer AS cu WITH (NOLOCK) ON cu.custid = tblTemp.Creator;

	-- Get currency name
	DECLARE @CurrencyName NVARCHAR(50)

	SELECT @CurrencyName = ex.currency
	FROM CustDB.dbo.custInfo AS ci WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	WHERE ci.custid = @CustId

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode			BIGINT,
			TransId			BIGINT,
			Stake			MONEY,
			Actual_Stake	MONEY,
			WinLost			MONEY,
			Commission		MONEY,
			SWinLost		MONEY,
			MWinLost		MONEY,
			AWinLost		MONEY,
			SComm			MONEY,
			AComm			MONEY,
			Comm			MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp(
			RefCode, TransId, Stake, Actual_Stake, WinLost, Commission, SWinLost, MWinLost, AWinLost, SComm, AComm, Comm
		)
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake,
			SUM(Actual_Stake) AS Actual_Stake,
			SUM(WinLost) AS WinLost,
			SUM(Commission) AS Commission,
			SUM(SWinLost) AS SWinLost,
			SUM(MWinLost) AS MWinLost,
			SUM(AWinLost) AS AWinLost,
			SUM(SComm) AS SComm,
			SUM(AComm) AS AComm,
			SUM(Comm) AS Comm
		FROM @Data
		WHERE RefCode <> 0
		GROUP BY RefCode
		HAVING COUNT(*) > 1

		IF EXISTS (SELECT 1 FROM @RefCodeTmp)
		BEGIN
			-- Update data for summmary ticket
			UPDATE b
			SET
				b.Stake = r.Stake,
				b.Actual_Stake = r.Actual_Stake,
				b.WinLost = r.WinLost,
				b.Commission = r.Commission,
				b.SWinLost = r.SWinLost,
				b.MWinLost = r.MWinLost,
				b.AWinLost = r.AWinLost,
				b.SComm = r.SComm,
				b.AComm = r.AComm,
				b.Comm = r.Comm,
				b.WalletType = 0
			FROM @Data AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE @Data
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE @Data
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	SELECT 
		b.SportType, b.LeagueId, b.HomeId, b.AwayId, b.MatchCode, b.Race, b.EventDate, b.VirtualRate, b.IsShowOTExRate, b.SDiscount, b.ADiscount, b.Discount, b.SettleTime, b.MatchId,
		b.TransId, b.BetId, b.RefNo, b.TransDate, b.OddsId, b.BetType, b.Hdp1, b.Hdp2, b.Odds, b.MOdds, b.FinalOdds, b.FinalOdds2, b.OddsType, b.BetTeam, b.Status, b.SettlementStatus,
		b.BetStatus, b.ComStatus, b.Stake, b.Actual_Stake, b.WinLost, b.Commission, b.LiveHomeScore, b.LiveAwayScore, b.LiveIndicator, b.FinalHomeScore, b.FinalAwayScore,
		b.HtHomeScore, b.HtAwayScore, b.Creator, b.Ip, b.Username, b.IsNeutral, b.ShowTime, b.SPositionTaking, b.MPositionTaking, b.APositionTaking, b.SPositionTaking2,
		b.MPositionTaking2, b.APositionTaking2, b.SComm, b.AComm, b.Comm, b.AWinLost, b.MWinLost, b.SWinLost, b.WinLostDate, b.BetCheck, b.TransDesc, b.OddsSpread, b.OriginalBetType,
		b.BetdaqId, b.ExtraInfo, b.WalletType, b.RefCode, b.CurrencyId, b.SiteId, b.DeviceType,
		@CurrencyName AS Currency
	FROM @Data b
	ORDER BY TransId ASC
END
GO
