/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_SelByRefNo_Mem]
	@CustId			INT,
	@ShadowIds		NVARCHAR(MAX) = NULL,
	@RefNo			BIGINT,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@IsCN88			BIT = 0
AS

/*
	Created by: 20220729@Kos
	Task: NAP - Left Panel - Bet List By Refno - SiteDB
	DB: DBSIG.bodb02

	Revisions:
		- 20220729@Kos: Scale out DBTRANS [Redmine: #175253]
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
					- Return new JackpotInfo column
					- Return ExtraInfo for show Max Payout
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20231108@Razor: Support WE Live Casino [Redmine: #195887]
		- 20231215@Razor: Support Live22 [Redmine: #197609]
		- 20240105@Razor: Extend data type [Redmine: #199259]
		- 20240118@Razor: HF of SEAL Entertainment [Redmine: #199994]
		- 20240207@Kos: Return GameId3rd to support Live22 Result [Redmine: #197609]
		- 20240222@Razor: Support Vitual Sports 4 [Redmine: #198619]
		- 20240327@Kos: Support UU Slots [Redmine: #192600]
		- 20240411@Razor: Return TranId3rd for Running ticket of Virtual Games/SportsLottery [Redmine: #203734]
		- 20240417@Razor: Support Saba xD [Redmine: #203371]
		- 20240419@Razor: Support Saba Coins [Redmine: #204003]
		- 20240626@Razor: Support FastSpin [Redmine: #205742]
		- 20240912@Razor: Support ON Casino [Redmine: #210026]
		- 20240920@Razor: Support VS2 Racing sports [Redmine: #211092]
		- 20241106@Razor: Support VS 5 - Virtually Sports [Redmine: #207589]
		- 20241202@Razor: Support GPI Live Casino [Redmine: #213486]
		- 20241219@Razor: Support VS6 - Betby Virtual Sports [Redmine: #212546]
		- 20250326@Benji: Support Upcoming Product (Microgaming Live Casino, Playtech Live Casino ) [Redmine: #221188]
		- 20250410@Benji: Remove Unnecessary Returned Data (Microgaming Live Casino, Playtech Live Casino) [Redmine: #221188]
		- 20250414@Razor: Support Direct Member [Redmine: #211969]
		- 20250428@Dave: change datatype for ExchangeID [RedmineID: #225676]
		- 20250513@Razor: Support SabaCoins multiple wallets [Redmine: #215807]
		- 20250730@Benji: Support Playtech RNG Jackpot - Support Automate Integration for Jackpot Betlist [Redmine: #234576]
		- 20250819@Razor: Support VS 2 - VS Tournament [Redmine: #235084]
		- 20250820@Benji: Support Playtech Live Jackpot [Redmine: #230127]
		- 20251027@Bobby: Support BetBuilder Hybrid Parlay [Redmine: #242255]
*/

BEGIN
	SET NOCOUNT ON

	-- List of bettype not allowed to delete
	DECLARE @tableBettypeNotAllowDelete TABLE(typeid INT NOT NULL)

	INSERT INTO @tableBettypeNotAllowDelete (typeid)
	SELECT 31 UNION ALL SELECT 32 UNION ALL SELECT 33 UNION ALL SELECT 41 UNION ALL SELECT 42 UNION ALL SELECT 43 UNION ALL
	SELECT 51 UNION ALL SELECT 52 UNION ALL SELECT 53 UNION ALL SELECT 54 UNION ALL SELECT 55 UNION ALL SELECT 56 UNION ALL
	SELECT 61 UNION ALL SELECT 62 UNION ALL SELECT 63 UNION ALL SELECT 64 UNION ALL SELECT 65 UNION SELECT 66

	DECLARE @Data TABLE (
		BetType				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				NVARCHAR(50),
		MatchCode			NVARCHAR(1000),
		Race				NVARCHAR(20),
		EventDate			DATETIME,
		VirtualRate			FLOAT,
		IsShowOTExRate		BIT,
		SDiscount			SMALLMONEY,
		ADiscount			SMALLMONEY,
		Discount			SMALLMONEY,
		PlayerDiscount		SMALLMONEY,
		HomeId				INT,
		AwayId				INT,
		SettleTime			DATETIME,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		FinalOdds			MONEY,
		FinalOdds2			MONEY,
		OddsType			TINYINT,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(200),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		SPositionTaking2	SMALLMONEY,
		MPositionTaking2	SMALLMONEY,
		APositionTaking2	SMALLMONEY,
		LiveIndicator		BIT,
		Modds				MONEY,
		CustId				INT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		LeagueId			INT,
		SportType			SMALLINT,
		Ip					VARCHAR(45),
		MatchId				INT,
		IsNeutral			BIT,
		AllowDelete			BIT,
		WinLost				MONEY,
		Commission			MONEY,
		SComm				MONEY,
		AComm				MONEY,
		Comm				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		ShowTime			NVARCHAR(50),
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(2000),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		OriginalBetType		INT,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		JackpotInfo			VARCHAR(50),
		WalletType			TINYINT,
		RefCode				BIGINT,
		CurrencyId			SMALLINT,
		SiteId				VARCHAR(20),
		DeviceType			TINYINT
	)

	DECLARE @TransId	BIGINT,
		@WinLostDate	SMALLDATETIME,
		@BetType		INT

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500), RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype(ProductID, Bettype, EventType, SubProduct, RefTable)
	SELECT ProductID, BetType, EventType, SubProduct, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT IN (903, 904, 913, 914, 999)
		AND ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 24, 26, 30, 31, 33)

	DECLARE @TmpShadow TABLE (CustId INT)	
	INSERT INTO @TmpShadow (CustId)
	SELECT value
	FROM STRING_SPLIT(@ShadowIds, ',')
	WHERE value IS NOT NULL AND value != ''
	
	INSERT INTO @TmpShadow (CustId)
	SELECT @CustId
	
	DECLARE @ProductJackpot TABLE(ProductId TINYINT)

	INSERT INTO @ProductJackpot(ProductId)
    SELECT DISTINCT ProductId
    FROM @SportBettype
    WHERE SubProduct LIKE 'Jackpot%'	
	
	-- FROM translog
	SELECT TOP(1)
		@TransId = b.translogid,
		@WinLostDate = b.winlostdate,
		@BetType = b.gameID,
		@RefNo = b.translogid
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.custid = @CustId
		AND b.translogid = @RefNo
		AND b.statusID IN (0, 1)
		AND ( sp.productid IN (8, 28, 38, 40, 43, 49, 63)
			OR sp.bettype BETWEEN 801 AND 899
			OR (sp.ProductId = 3 AND sp.EventType = 0))

	-- FROM bettrans
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@WinLostDate = b.winlostdate,
			@BetType = b.bettype,
			@RefNo = b.refno
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
			INNER JOIN @TmpShadow AS t ON t.CustId = b.CustId
		WHERE( b.transid = @RefNo
				OR ( b.refno = @RefNo
					AND (sp.productid IN (8, 28, 38, 40, 43, 49, 63)
						OR sp.bettype BETWEEN 801 AND 899
						OR (sp.productid = 3 AND sp.EventType = 0))))
			--exclude metric gaming running ticket
			AND (b.bettype NOT BETWEEN 801 AND 806
				OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))
	END

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- Bettrans
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- Sportbooks, Number Game, Virtual Sports, BetRadar Virtual Sports, Cash Out, Virtual Sports 3, Virtual Sport 4
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					CASE
						WHEN s.ProductID IN (1, 25) THEN m.GlobalShowTime
						ELSE m.eventdate
					END AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN b.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					b.playerdiscount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') AS settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					CASE
						WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						WHEN @IsCN88 = 1 AND s.ProductID IN (1, 5, 27) AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
						WHEN @IsCN88 = 1 AND s.ProductID IN (1, 5, 27) AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
						ELSE b.status
					END AS status,
					ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					CASE 
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR b.statusID NOT IN (0, 1, 112, 113, 111) THEN 0
						ELSE 1
					END AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					CASE
						WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
						ELSE m.showtime
					END AS ShowTime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,	-- For Myanmar Odds
					0 AS OriginalBetType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
						ELSE -1
					END AS BetdaqId,
					ISNULL(b.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
						ELSE 0
					END AS WalletType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
						ELSE 0
					END AS RefCode,
					b.currency,
					'' AS SiteId,
					b.DeviceType
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				WHERE b.transid = @TransId AND s.EventType = 1

				UNION ALL -- translog metric gaming
				SELECT
					tl.gameid AS BetType,
					tl.translogid AS transid,
					0 AS BetID,
					tl.translogid AS refno,
					m.matchcode,
					'' AS race,
					m.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					tl.sdiscount,
					CASE
						WHEN tl.mrecommend = -4 THEN 0
						ELSE tl.adiscount
					END,
					CASE
						WHEN tl.recommend IN (-3, -4) THEN 0
						ELSE tl.discount
					END,
					tl.playerdiscount,
					m.homeid,
					m.awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					tl.odds,
					0 finalodds,
					0 finalodds2,
					CASE
						WHEN tl.gameid IN (801, 803, 804, 805, 806) THEN CONVERT(TINYINT, ISNULL(tl.custom1, 0))
						ELSE 0
					END AS OddsType,
					tl.status,
					ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
					0 AS comstatus,
					tl.stake,
					tl.actual_stake,
					tl.transdate,
					'' AS betteam,
					tl.spositiontaking,
					tl.mpositiontaking,
					tl.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					tl.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					tl.ip,
					tl.eventID,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					CASE
						WHEN tl.gameID IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR tl.statusID NOT IN (0, 1, 112, 113, 111) THEN 0
						ELSE 1
					END AS allowdelete,
					0 AS WinLost,
					0 AS commission,
					0 AS scomm,
					0 AS acomm,
					0 AS comm,
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					m.showtime,
					tl.winlostdate,
					'' AS BetCheck,
					tl.transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					tl.currency,
					tl.SiteId,
					tl.DeviceType
				FROM
					dbo.translog AS tl WITH (NOLOCK) 
					INNER JOIN @SportBettype s ON s.Bettype = tl.gameid
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON tl.eventid = m.matchid
				WHERE
					s.Bettype BETWEEN 801 AND 899
					AND tl.translogid = @TransId
					AND tl.statusID IN (0, 1)

				-- Get more info for BetTrade tickets
				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 901)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					WHERE b.SportType = 1 AND b.BetType = 901
				END

				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 902)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.Comm = ISNULL(cb.awinlost, 0),
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
						LEFT JOIN dbo.bettrans AS cb WITH (NOLOCK)
							ON b.RefNo = cb.RefNo
							AND cb.BetType = 903
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.SportType = 1 AND b.BetType = 902
				END

				-- Get more info for CashOut tickets
				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.LiveIndicator = ob.liveindicator,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.OriginalBetType = ob.bettype,
						b.BetdaqId = ob.transid
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					WHERE b.BetType = 911
				END

				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.LiveIndicator = ob.liveindicator,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.OriginalBetType = ob.bettype,
						b.BetdaqId = ob.transid,
						b.Stake = cob.stake,
						b.Comm = ISNULL(cb.AWinLost, 0)
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
						LEFT JOIN dbo.bettrans AS cb WITH (NOLOCK)
							ON b.RefNo = cb.RefNo
							AND cb.BetType = 913
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.BetType = 912
				END
			END

			-- Bitcoin, Virtual Sport 5, vs6
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 5 AND bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					vs5.bettype,
					vs5.transid,
					ISNULL(vs5.betid, 0) AS BetID,
					vs5.refno,
					m.matchcode,
					'' AS race,
					m.EndTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					vs5.sdiscount,
					CASE
						WHEN vs5.mrecommend = -4 THEN 0
						ELSE vs5.adiscount
					END,
					CASE
						WHEN vs5.recommend IN (-3, -4) THEN 0
						ELSE vs5.discount
					END,
					vs5.playerdiscount,
					m.homeid,
					m.awayid,
					ISNULL(vs5.checktime,'') AS settleTime,
					vs5.hdp1,
					vs5.hdp2,
					vs5.odds,
					0 finalodds,
					0 finalodds2,
					vs5.OddsType,
					vs5.status AS status,
					0 AS SettlementStatus,
					0 AS comstatus,
					vs5.stake,
					vs5.actual_stake,
					vs5.transdate,
					vs5.betteam,
					vs5.spositiontaking,
					vs5.mpositiontaking,
					vs5.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					vs5.liveindicator,
					vs5.modds,
					vs5.custid,
					vs5.livehomescore,
					vs5.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.league3rdid,
					m.sporttype,
					vs5.ip,
					vs5.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					'' AS allowdelete,
					(vs5.winlost - vs5.actual_stake) AS WinLost,
					vs5.playercomm AS commission,
					(vs5.scomm - vs5.acomm) AS scomm,
					(vs5.acomm - vs5.comm) AS acomm,
					(vs5.comm - vs5.playercomm) AS comm,
					vs5.awinlost,
					vs5.mwinlost,
					vs5.swinlost,
					CONVERT(NVARCHAR(50), m.StartTime) AS ShowTime,
					vs5.winlostdate,
					vs5.BetCheck,
					ISNULL(vs5.transdesc, '') AS transdesc,
					ISNULL(vs5.oddsspread, 0) AS OddsSpread,	-- For Myanmar Odds
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(vs5.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					vs5.currency,
					'' AS SiteId,
					vs5.DeviceType
				FROM
					dbo.bettrans AS vs5 WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = vs5.bettype
					INNER JOIN dbo.match3rd AS m WITH (NOLOCK) ON vs5.matchid = m.match3rdid
				WHERE vs5.transid = @TransId AND s.EventType = 5

			END

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports), Mix Parlay (VS4), Mix Parlay (VS5)
			IF @BetType IN (9, 29, 2798, 2799, 10449, 11099)
			BEGIN
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					mix.bettype,
					mix.transid,
					ISNULL(mix.betid, 0) AS BetID,
					mix.refno,
					'' matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					mix.sdiscount,
					CASE
						WHEN mix.mrecommend = -4 THEN 0
						ELSE mix.adiscount
					END,
					CASE
						WHEN mix.recommend IN (-3, -4) THEN 0
						ELSE mix.discount
					END,
					mix.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' settleTime,
					mix.hdp1,
					mix.hdp2,
					mix.odds,
					0 finalodds,
					0 finalodds2,
					0 AS OddsType,
					CASE
						WHEN mix.status = 'running' THEN
							CASE
								WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
											WHERE bm.custid = mix.custid
												AND bm.refno = mix.refno
												AND (bm.status = 'waiting'
													OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
									THEN 'Waiting'
								ELSE mix.status
							END
						ELSE mix.status
					END AS Status,
					0 AS SettlementStatus,
					CASE WHEN mix.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					mix.stake,
					mix.actual_stake,
					mix.transdate,
					mix.betteam,
					mix.spositiontaking,
					mix.mpositiontaking,
					mix.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					0 liveindicator,
					mix.modds,
					mix.custid,
					mix.livehomescore,
					mix.liveawayscore,
					0,
					0,
					0 AS leagueid,
					0 AS sporttype,
					mix.ip,
					0 matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
					(mix.winlost - mix.actual_stake) AS WinLost,
					mix.playercomm AS commission,
					(mix.scomm - mix.acomm) AS scomm,
					(mix.acomm - mix.comm) AS acomm,
					(mix.comm - mix.playercomm) AS comm,
					mix.awinlost,
					mix.mwinlost,
					mix.swinlost,
					'' AS showtime,
					mix.winlostdate,
					ISNULL(mix.betcheck, '') AS BetCheck,
					IIF(mix.bettype = 29 AND mix.OddsSpread = 3, ISNULL(mix.transdesc, ''), '') AS transdesc,
					ISNULL(mix.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					mix.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					mix.currency,
					'' AS SiteId,
					mix.DeviceType
				FROM dbo.bettrans AS mix WITH (NOLOCK)
				WHERE
					mix.bettype IN (9, 29, 2798, 2799, 10449, 11099)
					AND mix.transid = @TransId
			END

			-- Keno, Lottery, NPH Promotion, Virtual Games, Table Games, Indo 4D, BBIN, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game)
			-- Sports Lottery, Player Tips, Saba Coins
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType AND (ProductID IN (8, 28, 37, 38, 40, 43, 47, 49, 63, 74, 81) OR (ProductID = 3 AND EventType = 0)))
			BEGIN
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					bro.bettype,
					bro.transid,
					ISNULL(bro.betid, 0) AS BetID,
					bro.refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bro.sdiscount,
					CASE
						WHEN bro.mrecommend = -4 THEN 0
						ELSE bro.adiscount
					END,
					CASE
						WHEN bro.recommend IN (-3, -4) THEN 0
						ELSE bro.discount
					END,
					bro.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN bro.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					CASE
						WHEN s.ProductID = 40 AND bro.status = 'Won' AND bro.modds = 0.25 THEN 'Half Won'
						WHEN s.ProductID = 40 AND bro.status = 'Lose' AND bro.modds = -0.25 THEN 'Half Lose'
						ELSE bro.status
					END AS status,
					0 AS SettlementStatus,
					'' AS comstatus,
					bro.stake,
					bro.actual_stake,
					bro.transdate,
					'' AS betteam,
					bro.spositiontaking,
					bro.mpositiontaking,
					bro.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					bro.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 37, 38, 40, 43, 47, 49, 63, 74, 81) THEN bro.matchid
						ELSE 0
					END AS sporttype,
					bro.ip,
					CASE
						WHEN s.ProductID = 74 THEN ISNULL(CAST(('<xml>' + bro.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
						ELSE 0
					END AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(bro.winlost - bro.actual_stake) AS WinLost,
					bro.playercomm AS commission,
					(bro.scomm - bro.acomm) AS scomm,
					(bro.acomm - bro.comm) AS acomm,
					(bro.comm - bro.playercomm) AS comm,
					bro.awinlost,
					bro.mwinlost,
					bro.swinlost,
					'' AS showtime,
					bro.winlostdate,
					CASE
						WHEN s.ProductID IN (3, 38, 63) THEN bro.betcheck
						WHEN s.ProductId = 8 THEN ISNULL(bro.comstatus, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN bro.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(bro.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					bro.currency,
					CASE 
						WHEN s.ProductId = 3 AND s.EventType = 0 THEN CONVERT(VARCHAR(20), bro.betdaqid)
						WHEN s.ProductId IN (38, 63) THEN CONVERT(VARCHAR(20), bro.betdaqid)
						ELSE '' 
					END AS SiteId,
					bro.DeviceType
				FROM dbo.bettrans AS bro WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = bro.bettype
				WHERE bro.transid = @TransId
					AND (s.ProductId IN (8, 28, 37, 38, 40, 43, 47, 49, 63, 74, 81)
							OR (s.ProductId = 3 AND s.EventType = 0))

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

			-- NG2
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 23 AND bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					ng2.bettype,
					ng2.transid,
					ISNULL(ng2.betid, 0) AS BetID,
					ng2.refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					ng2.sdiscount,
					CASE
						WHEN ng2.mrecommend = -4 THEN 0
						ELSE ng2.adiscount
					END,
					CASE
						WHEN ng2.recommend IN (-3, -4) THEN 0
						ELSE ng2.discount
					END,
					ng2.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					ng2.hdp1,
					ng2.hdp2,
					ng2.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					ng2.status,
					0 AS SettlementStatus,
					CASE WHEN ng2.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					ng2.stake,
					ng2.actual_stake,
					ng2.transdate,
					'' AS betteam,
					ng2.spositiontaking,
					ng2.mpositiontaking,
					ng2.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					ng2.custid,
					ng2.livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.Bettype BETWEEN 2681 AND 2699 THEN 218
						ELSE 0
					END AS sporttype,
					ng2.ip,
					ng2.betdaqid AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(ng2.winlost - ng2.actual_stake) AS WinLost,
					ng2.playercomm AS commission,
					(ng2.scomm - ng2.acomm) AS scomm,
					(ng2.acomm - ng2.comm) AS acomm,
					(ng2.comm - ng2.playercomm) AS comm,
					ng2.awinlost,
					ng2.mwinlost,
					ng2.swinlost,
					'' AS showtime,
					ng2.winlostdate,
					'' AS BetCheck,
					ISNULL(ng2.transdesc, '') AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					ng2.currency,
					'' AS SiteId,
					ng2.DeviceType
				FROM dbo.bettrans AS ng2 WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = ng2.bettype
				WHERE ng2.transid = @TransId
					AND s.ProductId = 23
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					ort.bettype,
					ort.transid,
					ISNULL(ort.betid, 0) AS BetID,
					ort.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					ort.sdiscount,
					CASE
						WHEN ort.mrecommend = -4 THEN 0
						ELSE ort.adiscount
					END,
					CASE
						WHEN ort.recommend IN (-3, -4) THEN 0
						ELSE ort.discount
					END,
					ort.playerdiscount,
					0 AS homeid,
					odds.teamid AS awayid,
					'' AS settleTime,
					ort.hdp1,
					ort.hdp2,
					ort.odds,
					0 AS finalodds,
					0 AS finalodds2,
					ort.oddstype AS OddsType,
					ort.status,
					0 AS SettlementStatus,
					CASE WHEN ort.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					ort.stake,
					ort.actual_stake,
					ort.transdate,
					ort.betteam,
					ort.spositiontaking,
					ort.mpositiontaking,
					ort.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					ort.liveindicator,
					ort.modds,
					ort.custid,
					ort.livehomescore,
					ort.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					ort.ip,
					ort.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					CASE
						WHEN ort.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR ort.statusID NOT IN (0, 1, 112, 113, 111) THEN 0
						ELSE 1
					END AS allowdelete,
					(ort.winlost - ort.actual_stake) AS WinLost,
					ort.playercomm AS commission,
					(ort.scomm - ort.acomm) AS scomm,
					(ort.acomm - ort.comm) AS acomm,
					(ort.comm - ort.playercomm) AS comm,
					ort.awinlost,
					ort.mwinlost,
					ort.swinlost,
					'' AS showtime,
					ort.winlostdate,
					ort.BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					ort.currency,
					'' AS SiteId,
					ort.DeviceType
				FROM dbo.bettrans AS ort WITH (NOLOCK)
					INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON ort.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE ort.bettype = 10
					AND ort.transid = @TransId
			END

			-- Virtual Horse Racing, VS2 Racing
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 3 AND bettype = @BetType)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					vs.bettype,
					vs.transid,
					'' AS BetID,
					vs.refno,
					'' AS matchcode, --Horse Number
					vs.oddsid AS Race, --Outright ID
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					vs.sdiscount,
					CASE
						WHEN vs.mrecommend = -4 THEN 0
						ELSE vs.adiscount
					END,
					CASE
						WHEN vs.recommend IN (-3, -4) THEN 0
						ELSE vs.discount
					END,
					vs.playerdiscount,
					0 AS homeID,
					0 AS awayID,
					'' settleTime,
					vs.hdp1,
					vs.hdp2,
					vs.odds,
					0 finalodds,
					0 finalodds2,
					vs.OddsType,
					vs.status,
					0 AS SettlementStatus,
					CASE WHEN vs.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					vs.stake,
					vs.actual_stake,
					vs.transdate,
					vs.betteam AS betteam,
					CASE WHEN vs.bettype = 1233 THEN bm.spositiontaking ELSE vs.spositiontaking END,
					CASE WHEN vs.bettype = 1233 THEN bm.mpositiontaking ELSE vs.mpositiontaking END,
					CASE WHEN vs.bettype = 1233 THEN bm.apositiontaking ELSE vs.apositiontaking END,
					CASE WHEN vs.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN vs.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN vs.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					vs.modds,
					vs.custid,
					vs.livehomescore,
					vs.liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					r.leagueid,
					r.sporttype,
					vs.ip,
					vs.matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					CASE 
						WHEN vs.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR vs.statusID NOT IN (0, 1, 112, 113, 111) THEN 0 
						ELSE 1 
					END AS allowdelete,
					(vs.winlost - vs.actual_stake) winlost,
					vs.playercomm AS commission,
					(vs.scomm - vs.acomm) AS scomm,
					(vs.acomm - vs.comm) AS acomm,
					(vs.comm - vs.playercomm) AS comm,
					vs.awinlost,
					vs.mwinlost,
					vs.swinlost,
					r.EventTime AS showtime,
					vs.winlostdate,
					vs.BetCheck,
					vs.transdesc AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					vs.currency,
					'' AS SiteId,
					vs.DeviceType
				FROM 
					dbo.bettrans AS vs WITH (NOLOCK)
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = vs.matchid
					INNER JOIN @SportBettype AS s ON s.BetType = vs.BetType 
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2
						FROM dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232
						) bm ON vs.refno = bm.refno
				WHERE
					vs.transid = @TransId
					AND s.EventType = 3
			END
			
			-- Keno, Lottery, Virtual Games, Table Games, Indo 4D, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery (translog)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
						WHERE (ProductID IN (8, 28, 38, 40, 43, 49, 63) OR (ProductID = 3 AND EventType = 0)) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					tl.gameid AS BetType,
					tl.translogid AS transid,
					0 AS betid,
					tl.translogid AS refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					tl.sdiscount,
					CASE
						WHEN tl.mrecommend = -4 THEN 0
						ELSE tl.adiscount
					END,
					CASE
						WHEN tl.recommend IN (-3, -4) THEN 0
						ELSE tl.discount
					END,
					tl.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN tl.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					tl.status,
					0 AS SettlementStatus,
					0 AS comstatus,
					tl.stake,
					tl.actual_stake,
					tl.transdate,
					'' AS betteam,
					tl.spositiontaking,
					tl.mpositiontaking,
					tl.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					tl.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 38, 40, 43, 49, 63) THEN tl.productID
						ELSE 0
					END AS sporttype,
					tl.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(-tl.actual_stake) AS WinLost,
					0 AS commission,
					0,
					0,
					0,
					0,
					0,
					0,
					'' AS showtime,
					tl.winlostdate,
					CASE
						WHEN s.ProductID IN (3) THEN tl.GameID3rd
						WHEN s.ProductID IN (38, 63) THEN tl.TranId3rd
						WHEN s.ProductId = 8 THEN ISNULL(tl.custom2, '')
						WHEN s.ProductId = 49 THEN ISNULL(tl.custom1, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN tl.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					tl.currency,
					tl.SiteId,
					tl.DeviceType
				FROM dbo.translog AS tl WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = tl.gameID
				WHERE tl.translogid = @TransId
					AND (s.ProductID IN (8, 28, 38, 40, 43, 49, 63)
							OR (s.ProductID = 3 AND s.EventType = 0))
					AND tl.statusID IN (0, 1)
			END

			-- RNG Casino Single Wallet, Voidbridge, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, Habanero, CG, VGaming
			-- AdvantPlay, AdvantPlay Mini, SEAL, MG RNGCasino, Jili, Live22, UU Slots, Saba xD
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
								OR (ProductID = 6 AND SubProduct <> '')
								OR RefTable = 1))
			BEGIN
				IF @WinLostDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- yesterday and later
				BEGIN
					-- Yesterday and later running ticket
					INSERT INTO @Data (
						BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
						, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
						, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
						, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
						, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
						, RefCode, CurrencyId, SiteId, DeviceType		
					)
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(brng.sdiscount) AS sdiscount,
						CASE
							WHEN brng.mrecommend = -4 THEN 0
							ELSE AVG(brng.adiscount) 
						END AS adiscount,
						CASE
							WHEN brng.recommend IN (-3, -4) THEN 0
							ELSE AVG(brng.discount) 
						END AS discount,
						AVG(brng.playerdiscount) AS playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						'Running' AS Status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(brng.stake) AS stake,
						SUM(brng.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(brng.spositiontaking) AS spositiontaking,
						AVG(brng.mpositiontaking) AS mpositiontaking,
						AVG(brng.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 32 THEN 248
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						0 AS WinLost,
						0 AS commission,
						0 AS scomm,
						0 AS acomm,
						0 AS comm,
						0 AS awinlost,
						0 AS mwinlost,
						0 AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN b.transdesc
							ELSE ''
						END AS transdesc,
						0 AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS currencyId,
						'' AS SiteId,
						b.DeviceType
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.transid = @TransId
						AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR (s.ProductId = 6 AND s.SubProduct <> '')
							OR s.RefTable = 1)
						AND brng.statusid IN (0, 1)
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.Bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.comstatus,
						b.matchid,
						b.transdesc,
						s.ProductID,
						b.DeviceType,
						brng.mrecommend,
						brng.recommend

					-- Yesterday and today settled ticket
					INSERT INTO @Data (
						BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
						, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
						, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
						, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
						, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
						, RefCode, CurrencyId, SiteId, DeviceType		
					)
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(brng.sdiscount) AS sdiscount,
						CASE
							WHEN brng.mrecommend = -4 THEN 0
							ELSE AVG(brng.adiscount) 
						END AS adiscount,
						CASE
							WHEN brng.recommend IN (-3, -4) THEN 0
							ELSE AVG(brng.discount) 
						END AS discount,
						AVG(brng.playerdiscount) AS playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN pj.ProductId IS NOT NULL
								THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						0 finalodds,
						0 finalodds2,
						0 AS OddsType,
						CASE 
							WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
							WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(brng.stake) AS stake,
						SUM(brng.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(brng.spositiontaking) AS spositiontaking,
						AVG(brng.mpositiontaking) AS mpositiontaking,
						AVG(brng.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 32 THEN 248
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						SUM(brng.winlost - brng.actual_stake) AS WinLost,
						SUM(brng.playercomm) AS commission,
						SUM(brng.scomm - brng.acomm) AS scomm,
						SUM(brng.acomm - brng.comm) AS acomm,
						SUM(brng.comm - brng.playercomm) AS comm,
						SUM(brng.awinlost) AS awinlost,
						SUM(brng.mwinlost) AS mwinlost,
						SUM(brng.swinlost) AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN b.transdesc
							ELSE ''
						END AS transdesc,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN ISNULL(SUM(brng.BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS currencyId,
						'' AS SiteId,
						b.DeviceType
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
						LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
					WHERE
						b.transid = @TransId
						AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR (s.ProductId = 6 AND s.SubProduct <> '')
							OR RefTable = 1)
						AND brng.statusid NOT IN (0, 1)
					GROUP BY
						b.transid,
						pj.ProductId,
						ISNULL(b.betid, 0),
						b.bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.comstatus,
						b.matchid,
						b.transdesc,
						s.ProductID,
						b.DeviceType,
						brng.recommend,
						brng.mrecommend
				END
				ELSE
				BEGIN
					-- Before yesterday settled ticket
					INSERT INTO @Data (
						BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
						, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
						, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
						, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
						, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
						, RefCode, CurrencyId, SiteId, DeviceType		
					)
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						b.sdiscount,
						CASE
							WHEN b.mrecommend = -4 THEN 0
							ELSE b.adiscount
						END,
						CASE
							WHEN b.recommend IN (-3, -4) THEN 0
							ELSE b.discount
						END,
						b.playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN b.odds
							ELSE 0
						END AS Odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						b.status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS betteam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 32 THEN 248
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS commission,
						(b.scomm - b.acomm) AS scomm,
						(b.acomm - b.comm) AS acomm,
						(b.comm - b.playercomm) AS comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN b.transdesc
							ELSE ''
						END AS transdesc,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN ISNULL(b.oddsspread, 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						b.currency,
						'' AS SiteId,
						b.DeviceType
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
						LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
					WHERE b.transid = @TransId
						AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR (s.ProductId = 6 AND s.SubProduct <> '')
							OR s.RefTable = 1)
				END
			END

			-- AG Casino, AllBet, SA Gaming, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming, PP Live Casino, FGG, YeeBet, WE
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE (ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR RefTable = 2) AND Bettype = @BetType)
			BEGIN
				IF @WinLostDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- yesterday and later
				BEGIN
					-- Yesterday and later running ticket
					INSERT INTO @Data (
						BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
						, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
						, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
						, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
						, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
						, RefCode, CurrencyId, SiteId, DeviceType		
					)
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(blc.sdiscount) AS sdiscount,
						CASE
							WHEN blc.mrecommend = -4 THEN 0
							ELSE AVG(blc.adiscount) 
						END AS adiscount,
						CASE
							WHEN blc.recommend IN (-3, -4) THEN 0
							ELSE AVG(blc.discount) 
						END AS discount,
						AVG(blc.playerdiscount) AS playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						'Running' AS Status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(blc.stake) AS stake,
						SUM(blc.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(blc.spositiontaking) AS spositiontaking,
						AVG(blc.mpositiontaking) AS mpositiontaking,
						AVG(blc.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						0 AS WinLost,
						0 AS commission,
						0 AS scomm,
						0 AS acomm,
						0 AS comm,
						0 AS awinlost,
						0 AS mwinlost,
						0 AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						'' AS transdesc,
						0 AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS CurrencyId,
						'' AS SiteId,
						b.DeviceType
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.transid = @TransId
						AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
						AND blc.statusID IN (0, 1)
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.Bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.comstatus,
						s.ProductID,
						b.matchid,
						b.DeviceType,
						blc.recommend,
						blc.mrecommend 

					-- Yesterday and today settled ticket
					INSERT INTO @Data (
						BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
						, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
						, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
						, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
						, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
						, RefCode, CurrencyId, SiteId, DeviceType		
					)
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(blc.sdiscount) AS sdiscount,
						CASE
							WHEN blc.mrecommend = -4 THEN 0
							ELSE AVG(blc.adiscount) 
						END AS adiscount,
						CASE
							WHEN blc.recommend IN (-3, -4) THEN 0
							ELSE AVG(blc.discount) 
						END AS discount,
						AVG(blc.playerdiscount) AS playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN pj.ProductId IS NOT NULL
								THEN ISNULL(AVG(CASE WHEN blc.statusID IN (111, 112, 113) THEN blc.ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						0 finalodds,
						0 finalodds2,
						0 AS OddsType,
						CASE 
							WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
							WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(blc.stake) AS stake,
						SUM(blc.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(blc.spositiontaking) AS spositiontaking,
						AVG(blc.mpositiontaking) AS mpositiontaking,
						AVG(blc.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						SUM(blc.winlost - blc.actual_stake) AS WinLost,
						SUM(blc.playercomm) AS commission,
						SUM(blc.scomm - blc.acomm) AS scomm,
						SUM(blc.acomm - blc.comm) AS acomm,
						SUM(blc.comm - blc.playercomm) AS comm,
						SUM(blc.awinlost) AS awinlost,
						SUM(blc.mwinlost) AS mwinlost,
						SUM(blc.swinlost) AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						'' AS transdesc,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN ISNULL(SUM(blc.BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS CurrencyId,
						'' AS SiteId,
						b.DeviceType
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
						LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
					WHERE
						b.transid = @TransId
						AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
						AND blc.statusID NOT IN (0, 1)
					GROUP BY
						b.transid,
						pj.ProductId,
						ISNULL(b.betid, 0),
						b.Bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.comstatus,
						s.ProductID,
						b.matchid,
						b.DeviceType,
						blc.recommend,
						blc.mrecommend,
						s.SubProduct
				END
				ELSE
				BEGIN
					-- Before yesterday settled ticket
					INSERT INTO @Data
					(
						BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
						, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
						, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
						, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
						, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
						, RefCode, CurrencyId, SiteId, DeviceType		
					)
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						b.sdiscount,
						CASE
							WHEN b.mrecommend = -4 THEN 0
							ELSE b.adiscount
						END,
						CASE
							WHEN b.recommend IN (-3, -4) THEN 0
							ELSE b.discount
						END,
						b.playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN b.odds
							ELSE 0
						END AS Odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						b.status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS betteam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						(b.winlost - b.actual_stake) AS WinLost,
						b.playercomm AS commission,
						(b.scomm - b.acomm) AS scomm,
						(b.acomm - b.comm) AS acomm,
						(b.comm - b.playercomm) AS comm,
						b.awinlost,
						b.mwinlost,
						b.swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						'' AS transdesc,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN ISNULL(b.oddsspread, 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS JackpotInfo,
						'' AS ExtraInfo,
						0 AS WalletType,
						0 AS RefCode,
						b.currency,
						'' AS SiteId,
						b.DeviceType
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
						LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
					WHERE b.transid = @TransId
						AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
				END
			END

			-- Get related Bonus/Cash tickets
			IF EXISTS ( SELECT 1 FROM @Data WHERE RefCode <> 0 )
			BEGIN
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					bo.bettype,
					bo.transid,
					ISNULL(bo.BetID,0) AS BetID,
					bo.refno,
					m.matchcode,
					'' AS race,
					m.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bo.sdiscount,
					CASE
						WHEN bo.mrecommend = -4 THEN 0
						ELSE bo.adiscount
					END,
					CASE
						WHEN bo.recommend IN (-3, -4) THEN 0
						ELSE bo.discount
					END,
					bo.playerdiscount,
					m.homeid,
					m.awayid,
					ISNULL(bo.checktime,'') settleTime,
					bo.hdp1,
					bo.hdp2,
					bo.odds,
					0 finalodds,
					0 finalodds2,
					bo.OddsType,
					CASE 
						WHEN bo.status = 'running' AND ISNULL(bo.SecAcceptFlag, 0) = 1 AND ISNULL(bo.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
						ELSE bo.status
					END AS status,
					ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
					CASE WHEN bo.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bo.stake,
					bo.actual_stake,
					bo.transdate,
					bo.betteam,
					bo.spositiontaking,
					bo.mpositiontaking,
					bo.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					bo.liveindicator,
					bo.modds,
					bo.custid,
					bo.livehomescore,
					bo.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					bo.ip,
					bo.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					CASE 
						WHEN bo.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR bo.statusID NOT IN (0, 1, 112, 113, 111) THEN 0 
						ELSE 1 
					END AS allowdelete,
					(bo.winlost-bo.actual_stake) AS winlost,
					bo.playercomm AS commission,
					(bo.scomm - bo.acomm) AS scomm,
					(bo.acomm - bo.comm) AS acomm,
					(bo.comm - bo.playercomm) AS comm,
					bo.awinlost,
					bo.mwinlost,
					bo.swinlost,
					m.showtime,
					bo.winlostdate,
					bo.BetCheck,
					ISNULL(bo.transdesc, '') AS transdesc,
					ISNULL(bo.oddsspread, 0) AS OddsSpread,	-- For Myanmar Odds
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(bo.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					ISNULL(bo.WalletType, 0) AS WalletType,
					ISNULL(bo.RefCode, 0) AS RefCode,
					bo.currency,
					'' AS SiteId,
					bo.DeviceType
				FROM
					dbo.bettrans AS bo WITH (NOLOCK)
					INNER JOIN @Data AS b1
						ON bo.custid = b1.CustId
						AND bo.winlostdate = b1.WinLostDate
						AND bo.RefCode = b1.RefCode
						AND bo.transid <> b1.transid
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON bo.matchid = m.matchid
			END
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
		INSERT INTO @TmpParlayData (RefNo,Odds,MOdds)
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
		INSERT INTO @TmpParlayData (RefNo,Odds,MOdds)
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
	
	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Display Cash/Bonus text for ticket from multiple wallets
	UPDATE @Data
	SET RefCode = 0
	WHERE RefCode <> 0

	-- BettransRnG tables
	SET @WinLostDate = NULL

	-- bettransRnG
	SELECT TOP(1)
		@TransId = b.transid,
		@WinLostDate = b.winlostdate,
		@BetType = b.gameID
	FROM dbo.bettransRnG AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.Bettype
	WHERE b.custid = @CustId AND b.transid = @RefNo

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- bettransRnG
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- RNG Casino Single Wallet, Macau Games, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, Habanero, CG, VGaming
			-- AdvantPlay, AdvantPlay Mini, SEAL, MG RNGCasino, Jili, Live22, UU Slots, Saba xD
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype 
						WHERE Bettype = @BetType
							AND (ProductID IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
								OR (ProductID = 6 AND SubProduct <> '')
								OR RefTable = 1))
			BEGIN
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					rng.gameID AS BetType,
					rng.transid,
					0 AS BetID,
					rng.refno,
					CASE
						WHEN s.productID IN (42) THEN ISNULL(rng.SiteID, '')
						ELSE rng.Additional
					END AS MatchCode,
					'' AS race,
					CASE
						WHEN s.productID IN (60) THEN rng.Transdate3rd
						ELSE ''
					END AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					rng.sdiscount,
					CASE
						WHEN rng.mrecommend = -4 THEN 0
						ELSE rng.adiscount
					END,
					CASE
						WHEN rng.recommend IN (-3, -4) THEN 0
						ELSE rng.discount
					END,
					rng.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN pj.ProductId IS NOT NULL AND rng.statusID IN (111, 112, 113) THEN ISNULL(rng.ContributionRate, 0)
						ELSE rng.odds
					END AS Odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					rng.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					rng.stake,
					rng.actual_stake,
					rng.transdate,
					rng.GameId3rd AS BetTeam,
					rng.spositiontaking,
					rng.mpositiontaking,
					rng.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					rng.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					rng.productID AS Sporttype,
					rng.ip,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(rng.winlost - rng.actual_stake) AS WinLost,
					rng.playercomm AS commission,
					(rng.scomm - rng.acomm) AS scomm,
					(rng.acomm - rng.comm) AS acomm,
					(rng.comm - rng.playercomm) AS comm,
					rng.awinlost,
					rng.mwinlost,
					rng.swinlost,
					'' AS showtime,
					rng.winlostdate,
					rng.TranId3rd AS BetCheck,
					rng.transdesc,
					CASE
						WHEN pj.ProductId IS NOT NULL AND rng.statusID IN (111, 112, 113) THEN ISNULL(rng.BetStake, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(rng.RefNo2, -1)
						ELSE -1
					END AS BetdaqId,
					rng.ExtraInfo,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(rng.JackpotInfo, '')
						ELSE ''
					END AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					rng.currency,
					rng.SiteId,
					rng.DeviceType
				FROM dbo.bettransRnG AS rng WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = rng.gameID
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE rng.transid = @TransId
					AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
						OR (s.ProductId = 6 AND s.SubProduct <> '')
						OR s.RefTable = 1)
			END
		END
	END

	-- BettransLC tables
	SET @WinLostDate = NULL

	-- bettransLC
	SELECT TOP(1)
		@TransId = b.transid,
		@WinLostDate = b.winlostdate,
		@BetType = b.gameID
	FROM dbo.bettransLC AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.custid = @CustId AND b.transid = @RefNo

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- bettransLC
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming, PP Live Casino, FGG, YeeBet, WE
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE (ProductID IN (11, 21, 45, 46, 52, 51, 57, 65, 70, 76, 80) OR RefTable = 2) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					blc.gameID AS BetType,
					blc.transid,
					0 AS BetID,
					blc.refno,
					CASE
						WHEN s.ProductID = 11 THEN ''
						ELSE blc.GameId3rd
					END AS matchcode,
					'' AS race,
					CASE
						WHEN s.ProductID IN (70, 90) THEN blc.TransDate3rd
						ELSE '' 
					END AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					blc.sdiscount,
					CASE
						WHEN blc.mrecommend = -4 THEN 0
						ELSE blc.adiscount
					END,
					CASE
						WHEN blc.recommend IN (-3, -4) THEN 0
						ELSE blc.discount
					END,
					blc.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (21, 45, 46, 51, 52, 57, 76, 80, 96) THEN blc.odds
						WHEN pj.ProductId IS NOT NULL AND blc.statusID IN (111, 112, 113) THEN ISNULL(blc.ContributionRate, 0)
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					blc.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					blc.stake,
					blc.actual_stake,
					blc.transdate,
					'' AS betteam,
					blc.spositiontaking,
					blc.mpositiontaking,
					blc.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					blc.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					blc.productID AS Sporttype,
					blc.ip,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(blc.winlost - blc.actual_stake) AS WinLost,
					blc.playercomm AS commission,
					(blc.scomm - blc.acomm) AS scomm,
					(blc.acomm - blc.comm) AS acomm,
					(blc.comm - blc.playercomm) AS comm,
					blc.awinlost,
					blc.mwinlost,
					blc.swinlost,
					'' AS showtime,
					blc.winlostdate,
					blc.TranId3rd AS BetCheck,
					blc.transdesc,
					CASE
						WHEN pj.ProductId IS NOT NULL AND blc.statusID IN (111, 112, 113) THEN ISNULL(blc.BetStake, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(blc.RefNo2, -1)
						ELSE -1
					END AS BetdaqId,
					blc.ExtraInfo,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(blc.JackpotInfo, '')
						ELSE ''
					END AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					blc.currency,
					blc.SiteId,
					blc.DeviceType
				FROM dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = blc.gameID
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE blc.transid = @TransId
					AND (s.ProductID IN (11, 21, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
			END
		END
	END

	-- Bettransg tables
	SET @WinLostDate = NULL

	-- bettransg
	SELECT TOP(1)
		@TransId = b.transid,
		@WinLostDate = b.winlostdate,
		@BetType = b.bettype
	FROM dbo.bettransg AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
	WHERE b.custid = @CustId AND b.transid = @RefNo

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- bettransg
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- SA Gaming
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (39) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					bg.bettype,
					bg.transid,
					0 AS BetID,
					bg.refno,
					ISNULL(blc.GameId3rd, '') AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bg.sdiscount,
					CASE
						WHEN blc.mrecommend = -4 THEN 0
						ELSE bg.adiscount
					END,
					CASE
						WHEN blc.recommend IN (-3, -4) THEN 0
						ELSE bg.discount
					END,
					bg.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					bg.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					bg.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					bg.stake,
					bg.actual_stake,
					bg.transdate,
					ISNULL(bg.BetID3rd, '') AS BetTeam,
					bg.spositiontaking,
					bg.mpositiontaking,
					bg.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					bg.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					ISNULL(blc.ProductID, 0) AS Sporttype,
					ISNULL(blc.ip, '') AS Ip,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					bg.winlost - bg.actual_stake AS WinLost,
					bg.playercomm AS Commission,
					bg.scomm - bg.acomm AS SComm,
					bg.acomm - bg.comm AS AComm,
					bg.comm - bg.playercomm AS Comm,
					bg.awinlost,
					bg.mwinlost,
					bg.swinlost,
					'' AS showtime,
					bg.winlostdate,
					ISNULL(bg.TransDesc, '') AS BetCheck,
					ISNULL(blc.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					bg.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b2.currency,
					bg.SiteId,
					bg.DeviceType
				FROM dbo.bettransg AS bg WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = bg.Bettype
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON bg.refno = blc.transid AND bg.custid = blc.CustId
					INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = blc.refno AND b2.custid = bg.CustId
				WHERE bg.transid = @TransId AND s.ProductID IN (39)
			END

			-- BBIN
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (47) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				(
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate, SDiscount, ADiscount, Discount, PlayerDiscount, HomeId, AwayId
					, SettleTime, Hdp1, Hdp2, Odds, FinalOdds, FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate, BetTeam
					, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2, APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore
					, LiveAwayScore, FinalHomeScore, FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, AllowDelete, WinLost, Commission, SComm, AComm, Comm
					, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType
					, RefCode, CurrencyId, SiteId, DeviceType		
				)
				SELECT
					bg.bettype,
					bg.transid,
					0 AS BetID,
					bg.refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bg.sdiscount,
					CASE
						WHEN b2.mrecommend = -4 THEN 0
						ELSE bg.adiscount
					END,
					CASE
						WHEN b2.recommend IN (-3, -4) THEN 0
						ELSE bg.discount
					END,
					bg.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					bg.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					bg.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					bg.stake,
					bg.actual_stake,
					bg.transdate,
					ISNULL(bg.betteam, '') AS BetTeam,
					bg.spositiontaking,
					bg.mpositiontaking,
					bg.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					bg.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					bg.matchid AS Sporttype,
					ISNULL(b2.ip, '') AS Ip,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					bg.winlost - bg.actual_stake AS WinLost,
					bg.playercomm AS Commission,
					bg.scomm - bg.acomm AS SComm,
					bg.acomm - bg.comm AS AComm,
					bg.comm - bg.playercomm AS Comm,
					bg.awinlost,
					bg.mwinlost,
					bg.swinlost,
					'' AS showtime,
					bg.winlostdate,
					ISNULL(bg.BetID3rd, '') AS BetCheck,
					ISNULL(bg.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b2.currency,
					bg.SiteId,
					bg.DeviceType
				FROM dbo.bettransg AS bg WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = bg.Bettype
					INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = bg.refno AND b2.custid = bg.CustId
				WHERE bg.transid = @TransId AND s.ProductID IN (47)
			END
		END
	END

	SELECT 
		b.BetType,
		b.TransId,
		b.BetId,
		b.RefNo,
		b.MatchCode,
		b.Race,
		b.EventDate,
		b.VirtualRate,
		b.IsShowOTExRate,
		b.SDiscount,
		b.ADiscount,
		b.Discount,
		b.PlayerDiscount,
		b.HomeId,
		b.AwayId,
		b.SettleTime,
		b.Hdp1,
		b.Hdp2,
		b.Odds,
		b.FinalOdds,
		b.FinalOdds2,
		b.OddsType,
		b.Status,
		b.SettlementStatus,
		b.ComStatus,
		b.Stake,
		b.Actual_Stake,
		b.TransDate,
		b.BetTeam,
		b.SPositionTaking,
		b.MPositionTaking,
		b.APositionTaking,
		b.SPositionTaking2,
		b.MPositionTaking2,
		b.APositionTaking2,
		b.LiveIndicator,
		b.Modds,
		b.CustId,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.FinalHomeScore,
		b.FinalAwayScore,
		b.LeagueId,
		b.SportType,
		b.Ip,
		b.MatchId,
		b.IsNeutral,
		b.AllowDelete,
		b.WinLost,
		b.Commission,
		b.SComm,
		b.AComm,
		b.Comm,
		b.AWinLost,
		b.MWinLost,
		b.SWinLost,
		b.ShowTime,
		b.WinLostDate,
		b.BetCheck,
		b.TransDesc,
		b.OddsSpread,
		b.OriginalBetType,
		b.BetdaqId,
		b.ExtraInfo,
		b.JackpotInfo,
		b.WalletType,
		b.RefCode,
		b.CurrencyId,
		b.SiteId,
		b.DeviceType,
		@CustId AS CustId,
		ex.currency,
		c.ugroup,
		c.username
	FROM @Data AS b
		LEFT JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid
		LEFT JOIN CustDB.dbo.Exchange AS ex WITH (NOLOCK) ON c.currency = ex.exchangeid
	ORDER BY b.TransId ASC
END
GO