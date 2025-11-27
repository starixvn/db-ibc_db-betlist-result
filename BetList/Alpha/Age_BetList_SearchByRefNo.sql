/*<info serverAlias="DBACC-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SearchByRefNo]
	@RefNo			BIGINT,
	@UplineId		INT,
	@RoleId			TINYINT,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created: 20230726@Kos
	Task: Alpha - Bet List - Search By RefNo
	DB: DBACC.bodb02

	Revisions:
		- 20230726@Kos: Search By RefNo [Redmine: #189384]
		- 20230727@Razor: Support Virtual Sports 3 [Redmine: #189205]
		- 20230825@Kos: Hotfix - Wrong result during Balance Up process [Redmine: #193193]
		- 20231004@Kos: Support Parlay Boost [Redmine: #194992]
		- 20231024@Kos: Hotfix - Parlay Boost range bettrans14 [Redmine: #195997]
		- 20231025@Razor: Support show max payout [Redmine: #194491]
			- Return new JackpotInfo column
			- Return ExtraInfo for show Max Payout
		- 20231027@Razor: Support new bettype of Virtual Sport 3 (LG) [Redmine: #194634]
		- 20231101@Razor: Return Device Type info [Redmine: #192667]
		- 20231215@Razor: Support Live22 [Redmine: #197609]
		- 20240105@Razor: Extend data type [Redmine: #199259]
		- 20240125@Razor: Support Project 777 - return LeagueGroupId [Redmine: #194591]
		- 20240228@Razor: Support WE Live Casino [Redmine: #195887]
		- 20240222@Razor: Support Vitual Sports 4 [Redmine: #198619]
		- 20240327@Kos: Support UU Slots [Redmine: #192600]
		- 20240411@Razor: Return TranId3rd for Running ticket of Virtual Games/SportsLottery [Redmine: #203734]
		- 20240417@Razor: Support Saba xD [Redmine: #203371]
		- 20240626@Razor: Support FastSpin [Redmine: #205742]
		- 20240717@Razor: Support FA CHAI [Redmine: #206633]
		- 20240806@Razor: Support Nextspin [Redmine: #199985]
		- 20240912@Razor: Support ON Casino [Redmine: #210026]
		- 20241023@Razor: Support Playtech [Redmine: #210553]
		- 20241023@Razor: Support GPI [Redmine: #207173]
		- 20241106@Razor: Support VS 5 - Virtually Sports [Redmine: #207589]
		- 202411202@Razor: Support GPI Live Casino [Redmine: #213486]
		- 20241231@Razor: Support PLAY STAR [Redmine: #208023]
		- 20250106@Razor: SA Gaming support Saba Plus [Redmine: #215645]
		- 20250213@Razor: Support ASKMESLOT [Redmine: #216976]
		- 20250218@Razor: Support SABA Keno [Redmine: #214757]
		- 20250312@Benji: Support Funky Games [Redmine: #218176]
		- 20250325@Benji: Support Upcoming Product (HOTDOG, Kiron VS7, Microgaming Live Casino, GPI Lottery, ODIN GAMING, Playtech Live Casino ) [Redmine: #221188]
		- 20250410@Benji: Remove Unnecessary Returned Data (Kiron VS7, Microgaming Live Casino, Playtech Live Casino) [Redmine: #221188]
		- 20250414@Razor: Support Direct Member [Redmine: #211969]
		- 20250416@Dave: change datatype for ExchangeID [RedmineID: #221098]
		- 20250418@Benji: Support Rich Gaming [Redmine: #224687]
		- 20250515@Benji: Support W Casino [Redmine: #227510]
		- 20250617@Benji: Support ClotPlay, AI Gaming [Redmine: #229171]
		- 20250814@Benji: Support Smartsoft [Redmine: #210944]
		- 20250815@Benji: Support 3rd Products - Automate [Redmine: #210944]
		- 20251030@Virgil: Support BetBuilder+ Hybrid Parlay [Redmine: #242378]
*/

BEGIN
	SET NOCOUNT ON

	-- Get SportBetTypeMatrix
	DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype (ProductID, Bettype, EventType, RefTable)
	SELECT ProductID, BetType, EventType, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID NOT IN (2, 4, 7, 9, 10, 11, 12, 13, 14, 15, 17, 19, 24, 25, 26, 30, 31, 33, 43, 59)
		AND BetType NOT IN (71, 72, 901, 902, 903, 904, 999)
		AND BetType NOT BETWEEN 801 AND 899

	DECLARE @Data TABLE (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Username			NVARCHAR(50),
		Currency			NVARCHAR(50),
		CurrencyId			INT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(200),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
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
		ComStatus			NVARCHAR(20),
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		HtHomeScore			SMALLINT,
		HtAwayScore			SMALLINT,
		FinalHomeScore		SMALLINT,
		FinalAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(1000),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		Placing				NVARCHAR(20),
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(2000),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		JackpotInfo			VARCHAR(50),
		SiteId				VARCHAR(20),
		WhTicket			TINYINT,
		DeviceType			TINYINT,
		LeagueGroupId		SMALLINT
	)

	DECLARE @Detail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	)

	DECLARE
		@CustId			INT,
		@MemberUplineId	INT,
		@TransId		BIGINT,
		@WinLostDate	SMALLDATETIME,
		@ProductId		TINYINT,
		@EventType		TINYINT,
		@RefTable		TINYINT,
		@Product		VARCHAR(30),
		@WhTicket		TINYINT		= 0

	-- Translog range
	IF @WhTicket = 0
	BEGIN
		SELECT TOP(1)
			@TransId = b.translogid,
			@MemberUplineId = CASE @RoleId
								WHEN 2 THEN b.recommend
								WHEN 3 THEN b.mrecommend
								WHEN 4 THEN b.srecommend
								ELSE 0
							END,
			@CustId = b.custid,
			@WinLostDate = b.winlostdate,
			@ProductId = s.ProductID,
			@EventType = s.EventType,
			@RefTable = s.RefTable,
			@WhTicket = 1		-- translog
		FROM dbo.translog AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON b.gameID = s.bettype
		WHERE b.translogid = @RefNo
			AND s.RefTable = 3
			AND b.statusID IN (0, 1)
	END

	-- Bettrans range
	IF @WhTicket = 0 OR @UplineId <> @MemberUplineId
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@MemberUplineId = CASE @RoleId
								WHEN 2 THEN b.recommend
								WHEN 3 THEN b.mrecommend
								WHEN 4 THEN b.srecommend
								ELSE 0
							END,
			@CustId = b.custid,
			@WinLostDate = b.winlostdate,
			@ProductId = s.ProductID,
			@EventType = s.EventType,
			@RefTable = s.RefTable,
			@WhTicket = 2		-- bettrans
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
		WHERE (b.transid = @RefNo
				OR (b.refno = @RefNo AND s.RefTable = 3))
			AND b.winlostdate > @MoveBetsDay
	END

	-- Bettrans14 range
	IF @WhTicket = 0 OR @UplineId <> @MemberUplineId
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@MemberUplineId = CASE @RoleId
								WHEN 2 THEN b.recommend
								WHEN 3 THEN b.mrecommend
								WHEN 4 THEN b.srecommend
								ELSE 0
							END,
			@CustId = b.custid,
			@WinLostDate = b.winlostdate,
			@ProductId = s.ProductID,
			@EventType = s.EventType,
			@RefTable = s.RefTable,
			@WhTicket = 3		-- bettrans14
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
		WHERE (b.transid = @RefNo
				OR (b.refno = @RefNo AND s.RefTable = 3))
			AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
	END

	-- Check belonging
	IF @UplineId <> @MemberUplineId
		SET @WhTicket = 0

	SET @Product = CASE
						WHEN @ProductId = 6 THEN 'OneRNG'		-- RNG Casino
						WHEN @ProductId = 8 THEN 'Keno'
						WHEN @ProductId = 21 THEN 'AllBet'
						WHEN @ProductId = 22 THEN 'VB'			-- Macau Games
						WHEN @ProductId = 23 THEN 'NG2'
						WHEN @ProductId = 28 THEN 'Lottery'
						WHEN @ProductId = 32 THEN 'PP'			-- Pragmatic Play Casino
						WHEN @ProductId = 34 THEN 'CC'			-- Card Club
						WHEN @ProductId = 36 THEN 'SG'			-- Spadegaming
						WHEN @ProductId = 37 THEN 'SPR'			-- Saba Promotion
						WHEN @ProductId = 38 THEN 'VRG'			-- Virtual Games
						WHEN @ProductId = 39 THEN 'SAG'			-- SA Gaming
						WHEN @ProductId = 40 THEN 'TG'			-- Table Games
						WHEN @ProductId = 42 THEN 'SBC'			-- Saba.club
						WHEN @ProductId = 43 THEN 'I4D'			-- Indo 4D
						WHEN @ProductId = 45 THEN 'SXG'			-- Sexy Gaming
						WHEN @ProductId = 46 THEN 'IBCLC'		-- IBCBet Live Casino
						WHEN @ProductId = 47 THEN 'BBIN'
						WHEN @ProductID = 48 THEN 'GPIRNG'		-- GPI
						WHEN @ProductId = 49 THEN 'VS3'			-- Virtual Sports 3
						WHEN @ProductId = 50 THEN 'RNGW'		-- RNG War
						WHEN @ProductId = 51 THEN 'WM'			-- WM Live Casino
						WHEN @ProductId = 52 THEN 'ION'
						WHEN @ProductId = 55 THEN 'PGS'			-- PG Soft
						WHEN @ProductId = 56 THEN 'JK'			-- Joker
						WHEN @ProductId = 57 THEN 'BG'			-- Big Gaming
						WHEN @ProductId = 60 THEN 'MXG'			-- MaxGame
						WHEN @ProductId = 61 THEN 'HB'			-- Habanero
						WHEN @ProductId = 62 THEN 'CG'			-- CG
						WHEN @ProductId = 63 THEN 'SLT'			-- SLT
						WHEN @ProductId = 65 THEN 'PPL'			-- PP Live Casino
						WHEN @ProductId = 66 THEN 'VGA'			-- Vgaming
						WHEN @ProductId = 67 THEN 'AP'			-- AdvantPlay
						WHEN @ProductId = 68 THEN 'APM'			-- AdvantPlay Mini
						WHEN @ProductId = 69 THEN 'BTC'			-- Bitcoin
						WHEN @ProductId = 70 THEN 'FGGL'		-- FGG
						WHEN @ProductId = 72 THEN 'SEA'			-- SEAL Entertainment
						WHEN @ProductId = 73 THEN 'MGRNG'		-- MG-RNG
						WHEN @ProductId = 75 THEN 'JIG'			-- Jili
						WHEN @ProductID = 76 THEN 'YB'			-- YeeBet
						WHEN @ProductID = 77 THEN 'LG'			-- Virtual Sports 3
						WHEN @ProductID = 78 THEN 'UUSL'		-- UU Slots
						WHEN @ProductID = 79 THEN 'L22'			-- Live22
						WHEN @ProductID = 80 THEN 'WE'			-- WE
						WHEN @ProductID = 84 THEN 'GPILT'		-- GPI Lottery
						WHEN @ProductID = 85 THEN 'NS'			-- Nextspin
						WHEN @ProductID = 86 THEN 'SNG'			-- Saba xD
						WHEN @ProductID = 87 THEN 'FS'			-- FastSpin
						WHEN @ProductID = 89 THEN 'FAC'			-- FA CHAI
						WHEN @ProductID = 90 THEN 'GPILC'		-- GPI Live Casino
						WHEN @ProductID = 91 THEN 'PS'			-- PLAY STAR
						WHEN @ProductID = 95 THEN 'HOT'			-- HOTDOG
						WHEN @ProductID = 96 THEN 'ON'			-- ON Casino
						WHEN @ProductID = 98 THEN 'WLC'			-- W Casino
						WHEN @ProductID = 100 THEN 'PTRNG'		-- Playtech
						WHEN @ProductID = 101 THEN 'PTLC'		-- Playtech Live Casino
						WHEN @ProductID = 102 THEN 'SBK'		-- SABA Keno
						WHEN @ProductID = 103 THEN 'ASK'		-- ASKMESLOT
						WHEN @ProductID = 104 THEN 'FG'			-- Funky Games
						WHEN @ProductID = 105 THEN 'ODG'		-- ODIN GAMING
						WHEN @ProductID = 107 THEN 'MGLC'		-- Microgaming Live
						WHEN @ProductID = 108 THEN 'RGRNG'		-- Rich Gaming
						WHEN @ProductID = 109 THEN 'CPRNG'		-- ClotPlay
						WHEN @ProductID = 110 THEN 'AIG'		-- AI Gaming
						WHEN @EventType = 0 AND @ProductId = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN @EventType = 0 AND @ProductId = 3 THEN 'H5LG'			-- Happy 5 Linked Games (Number Game)
						WHEN @EventType = 0 AND @ProductId = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
						WHEN @EventType = 0 AND @ProductId = 83 THEN 'ParlayVS4'	-- Virtual Sports 4 Parlay
						WHEN @EventType = 0 AND @ProductId = 88 THEN 'ParlayVS5'	-- Virtual Sports 5 Parlay
						WHEN @EventType = 1 AND @ProductId = 1 THEN 'SB'			-- Sportsbook
						WHEN @EventType = 1 AND @ProductId = 3 THEN 'NG'			-- Number Game
						WHEN @EventType = 1 AND @ProductId = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN @EventType = 1 AND @ProductId = 27 THEN 'VS2'			-- Betradar Virtual Sports
						WHEN @EventType = 1 AND @ProductId = 83 THEN 'VS4'			-- Virtual Sports 4
						WHEN @EventType = 5 AND @ProductId = 88 THEN 'VS5'			-- Virtual Sports 5
						WHEN @EventType = 2 AND @ProductId = 1 THEN 'Outright'
						WHEN @EventType = 3 AND @ProductId = 5 THEN 'VR'			-- Virtual Sports Racing						
						ELSE 'Unknown'
					END

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

	IF @WhTicket = 1	-- translog
	BEGIN
		INSERT INTO @Data (
			TransId, RefNo, CustId, Username, Currency, CurrencyId, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SettlementStatus, TransDate,
			WinLostDate, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, ComStatus,
			LiveIndicator, LiveHomeScore, LiveAwayScore, HtHomeScore, HtAwayScore, FinalHomeScore, FinalAwayScore, Ip, LeagueId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral, Placing,
			ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, SiteId, WhTicket, DeviceType, LeagueGroupId
		)
		SELECT
			b.translogid AS TransId,
			b.translogid AS RefNo,
			b.custid,
			b.Username,
			b.CurrencyName AS Currency,
			b.currency AS CurrencyId,
			b.productID AS SportType,
			b.gameID AS BetType,
			0 AS BetId,
			'' AS BetTeam,
			0 AS Hdp1,
			0 AS Hdp2,
			0 AS OddsType,
			b.odds,
			0 AS MOdds,
			0 AS OddsSpread,
			b.stake,
			b.actual_stake,
			b.status,
			0 AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			0 AS WinLost,
			0 AS AWinLost,
			0 AS MWinLost,
			0 AS SWinLost,
			0 AS PlayerComm,
			0 AS Comm,
			0 AS AComm,
			0 AS SComm,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.tpositiontaking,
			CASE
				WHEN b.recommend IN (-3, -4) THEN 0
				ELSE b.discount 
			END AS ADiscount,
			CASE
				WHEN b.mrecommend = -4 THEN 0
				ELSE b.adiscount
			END AS MDiscount,
			b.sdiscount,
			0 AS ComStatus,
			0 AS LiveIndicator,
			0 AS LiveHomeScore,
			0 AS LiveAwayScore,
			0 AS HtHomeScore,
			0 AS HtAwayScore,
			0 AS FinalHomeScore,
			0 AS FinalAwayScore,
			b.ip,
			0 AS LeagueId,
			0 AS MatchId,
			'' AS MatchCode,
			'' AS Race,
			b.winlostdate AS EventDate,
			0 AS HomeId,
			0 AS AwayId,
			'' AS BetStatus,
			0 AS IsNeutral,
			'' AS Placing,
			'' AS ShowTime,
			CASE
				WHEN @Product IN ('Keno') THEN ISNULL(b.custom2, '')
				WHEN @Product IN ('H5LG') THEN b.Gameid3rd
				WHEN @Product IN ('VRG', 'SLT') THEN b.TranId3rd
				WHEN @Product IN ('VS3') THEN ISNULL(b.custom1, '')
				ELSE ''
			END AS BetCheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			'' AS JackpotInfo,
			ISNULL(b.SiteId, '') AS SiteId,
			1 AS WhTicket,
			b.DeviceType,
			0 AS LeagueGroupId
		FROM dbo.translog AS b WITH (NOLOCK)
		WHERE b.translogid = @TransId
	END
	ELSE IF @WhTicket = 2	-- Bettrans
	BEGIN
		DECLARE @TmpData TABLE (
			Odds			MONEY,
			Stake			MONEY,
			Actual_Stake	MONEY,
			Status			NVARCHAR(10),
			WinLost			MONEY,
			AWinLost		MONEY,
			MWinLost		MONEY,
			SWinLost		MONEY,
			PlayerComm		MONEY,
			Comm			MONEY,
			AComm			MONEY,
			SComm			MONEY,
			APositiontaking	SMALLMONEY,
			MPositiontaking	SMALLMONEY,
			SPositiontaking	SMALLMONEY,
			TPositiontaking	SMALLMONEY,
			Discount		SMALLMONEY,
			ADiscount		SMALLMONEY,
			SDiscount		SMALLMONEY,
			OddsSpread		MONEY
		)

		IF @RefTable IN (1, 2) AND @WinLostDate >= @Yesterday
		BEGIN
			-- bettransRnG
			IF @RefTable = 1
			BEGIN
				INSERT INTO @TmpData (Odds, Stake, Actual_Stake, Status, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositiontaking, MPositiontaking, SPositiontaking, TPositiontaking, Discount, ADiscount, SDiscount, OddsSpread)
				SELECT
					CASE
						WHEN @Product IN ('OneRNG', 'PP', 'SG') THEN ISNULL(AVG(CASE WHEN statusID IN (111, 112, 113) THEN ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					SUM(stake) AS Stake,
					SUM(actual_stake) AS Actual_Stake,
					CASE
						WHEN SUM(winlost - actual_stake) > 0 THEN 'Won'
						WHEN SUM(winlost - actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					SUM(winlost - actual_stake) AS WinLost,
					SUM(awinlost) AS AWinLost,
					SUM(mwinlost) AS MWinLost,
					SUM(swinlost) AS SWinLost,
					SUM(playercomm) AS PlayerComm,
					SUM(comm - playercomm) AS Comm,
					SUM(acomm - comm) AS AComm,
					SUM(scomm - acomm) AS SComm,
					AVG(apositiontaking) AS APositiontaking,
					AVG(mpositiontaking) AS MPositiontaking,
					AVG(spositiontaking) AS SPositiontaking,
					AVG(tpositiontaking) AS TPositiontaking,
					AVG(discount) AS Discount,
					AVG(adiscount) AS ADiscount,
					AVG(sdiscount) AS SDiscount,
					CASE
						WHEN @Product IN ('OneRNG', 'PP', 'SG') THEN ISNULL(SUM(BetStake), 0)
						ELSE 0
					END AS OddsSpread
				FROM dbo.bettransRnG WITH (NOLOCK)
				WHERE RefNo = @TransId AND statusID NOT IN (0, 1)
				GROUP BY RefNo

				INSERT INTO @TmpData (Odds, Stake, Actual_Stake, Status, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositiontaking, MPositiontaking, SPositiontaking, TPositiontaking, Discount, ADiscount, SDiscount, OddsSpread)
				SELECT
					0 AS Odds,
					SUM(stake) AS Stake,
					SUM(actual_stake) AS Actual_Stake,
					'Running' AS Status,
					0 AS WinLost,
					0 AS AWinLost,
					0 AS MWinLost,
					0 AS SWinLost,
					0 AS PlayerComm,
					0 AS Comm,
					0 AS AComm,
					0 AS SComm,
					AVG(apositiontaking) AS APositiontaking,
					AVG(mpositiontaking) AS MPositiontaking,
					AVG(spositiontaking) AS SPositiontaking,
					AVG(tpositiontaking) AS TPositiontaking,
					AVG(discount) AS Discount,
					AVG(adiscount) AS ADiscount,
					AVG(sdiscount) AS SDiscount,
					0 AS OddsSpread
				FROM dbo.bettransRnG WITH (NOLOCK)
				WHERE RefNo = @TransId AND statusID IN (0, 1)
				GROUP BY RefNo
			END

			-- bettransLC
			IF @RefTable = 2
			BEGIN
				INSERT INTO @TmpData (Odds, Stake, Actual_Stake, Status, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositiontaking, MPositiontaking, SPositiontaking, TPositiontaking, Discount, ADiscount, SDiscount, OddsSpread)
				SELECT
					0 AS Odds,
					SUM(stake) AS Stake,
					SUM(actual_stake) AS Actual_Stake,
					CASE
						WHEN SUM(winlost - actual_stake) > 0 THEN 'Won'
						WHEN SUM(winlost - actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					SUM(winlost - actual_stake) AS WinLost,
					SUM(awinlost) AS AWinLost,
					SUM(mwinlost) AS MWinLost,
					SUM(swinlost) AS SWinLost,
					SUM(playercomm) AS PlayerComm,
					SUM(comm - playercomm) AS Comm,
					SUM(acomm - comm) AS AComm,
					SUM(scomm - acomm) AS SComm,
					AVG(apositiontaking) AS APositiontaking,
					AVG(mpositiontaking) AS MPositiontaking,
					AVG(spositiontaking) AS SPositiontaking,
					AVG(tpositiontaking) AS TPositiontaking,
					AVG(discount) AS Discount,
					AVG(adiscount) AS ADiscount,
					AVG(sdiscount) AS SDiscount,
					0 AS OddsSpread
				FROM dbo.bettransLC WITH (NOLOCK)
				WHERE RefNo = @TransId AND statusID NOT IN (0, 1)
				GROUP BY RefNo

				INSERT INTO @TmpData (Odds, Stake, Actual_Stake, Status, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositiontaking, MPositiontaking, SPositiontaking, TPositiontaking, Discount, ADiscount, SDiscount, OddsSpread)
				SELECT
					0 AS Odds,
					SUM(stake) AS Stake,
					SUM(actual_stake) AS Actual_Stake,
					'Running' AS Status,
					0 AS WinLost,
					0 AS AWinLost,
					0 AS MWinLost,
					0 AS SWinLost,
					0 AS PlayerComm,
					0 AS Comm,
					0 AS AComm,
					0 AS SComm,
					AVG(apositiontaking) AS APositiontaking,
					AVG(mpositiontaking) AS MPositiontaking,
					AVG(spositiontaking) AS SPositiontaking,
					AVG(tpositiontaking) AS TPositiontaking,
					AVG(discount) AS Discount,
					AVG(adiscount) AS ADiscount,
					AVG(sdiscount) AS SDiscount,
					0 AS OddsSpread
				FROM dbo.bettransLC WITH (NOLOCK)
				WHERE RefNo = @TransId AND statusID IN (0, 1)
				GROUP BY RefNo
			END
		END

		INSERT INTO @Data (
			TransId, RefNo, CustId, Username, Currency, CurrencyId, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SettlementStatus, TransDate,
			WinLostDate, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, ComStatus,
			LiveIndicator, LiveHomeScore, LiveAwayScore, HtHomeScore, HtAwayScore, FinalHomeScore, FinalAwayScore, Ip, LeagueId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral, Placing,
			ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, SiteId, WhTicket, DeviceType, LeagueGroupId
		)
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.Username,
			b.CurrencyName AS Currency,
			b.currency AS CurrencyId,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'VB', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SPR', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 
					'SAG', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 
					'BBIN', 'RNGW', 'SEA', 'IBCLC', 'ION', 'PPL', 'L22', 'WE') THEN b.matchid
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.sporttype
				WHEN @Product IN ('BTC', 'VS5') THEN m3rd.SportType
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @Product IN ('VR') THEN vr.SportType
				WHEN @Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213
				WHEN @Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214
				WHEN @Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215
				WHEN @Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216
				WHEN @Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218
				WHEN @RefTable IN (1, 2) THEN b.matchid
				WHEN @EventType = 3 THEN vrc.SportType
				ELSE 0
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5') THEN b.betteam
				WHEN @EventType = 3 THEN b.betteam
				ELSE ''
			END AS BetTeam,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'BTC', 'NG2', 'LG', 'ParlayVS4', 'VS5', 'ParlayVS5') THEN b.hdp1
				ELSE 0
			END AS Hdp1,
			CASE
				WHEN @Product IN ('SB', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2', 'LG', 'ParlayVS4', 'VS5', 'ParlayVS5') THEN b.hdp2
				ELSE 0
			END AS Hdp2,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG', 'VS4', 'VS5') THEN b.oddstype
				WHEN @EventType = 3 THEN b.oddstype
				ELSE 0
			END AS OddsType,
			CASE
				WHEN @Product IN ('VB', 'PP', 'OneRNG', 'Allbet', 'SBC', 'VGA', 'SG') AND x.Odds IS NOT NULL THEN x.Odds
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'Keno', 'ParlayVS2', 'Lottery', 
					'OneRNG', 'VRG', 'TG', 'I4D', 'PP', 'SBC', 'SLT', 'VGA', 'H5LG', 'SG', 'VS3', 'BTC', 'NG2', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5') THEN b.odds
				WHEN @EventType = 3 THEN b.odds
				ELSE 0
			END AS Odds,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5') THEN b.modds
				WHEN @EventType = 3 THEN b.modds
				ELSE 0
			END AS MOdds,
			CASE
				WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
				WHEN @Product IN ('SB', 'PP', 'SBC', 'VGA', 'SG', 'Parlay') THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			CASE
				WHEN @RefTable IN (1, 2) AND x.Stake IS NOT NULL THEN x.Stake
				ELSE b.stake
			END AS Stake,
			CASE
				WHEN @RefTable IN (1, 2) AND x.Actual_Stake IS NOT NULL THEN x.Actual_Stake
				ELSE b.actual_stake
			END AS Actual_Stake,
			CASE
				WHEN @RefTable IN (1, 2) AND x.status IS NOT NULL THEN x.status
				WHEN @Product IN ('SB')
					AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				WHEN @Product = 'Parlay' AND b.status = 'running' THEN
						CASE
							WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
										WHERE bm.custid = b.custid
											AND bm.refno = b.refno
											AND (bm.status = 'waiting'
												OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
								THEN 'Waiting'
							ELSE b.status
						END
				WHEN @Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
				WHEN @Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
				ELSE b.status
			END AS Status,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(m.SettlementStatus, 0)
				ELSE 0
			END AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			CASE
				WHEN @RefTable IN (1, 2) AND x.WinLost IS NOT NULL THEN x.WinLost
				ELSE b.winlost - b.actual_stake
			END AS WinLost,
			CASE
				WHEN @RefTable IN (1, 2) AND x.AWinLost IS NOT NULL THEN x.AWinLost
				ELSE b.awinlost
			END AS AWinLost,
			CASE
				WHEN @RefTable IN (1, 2) AND x.MWinLost IS NOT NULL THEN x.MWinLost
				ELSE b.mwinlost
			END AS MWinLost,
			CASE
				WHEN @RefTable IN (1, 2) AND x.SWinLost IS NOT NULL THEN x.SWinLost
				ELSE b.swinlost
			END AS SWinLost,
			CASE
				WHEN @RefTable IN (1, 2) AND x.PlayerComm IS NOT NULL THEN x.PlayerComm
				ELSE b.playercomm
			END AS PlayerComm,
			CASE
				WHEN @RefTable IN (1, 2) AND x.Comm IS NOT NULL THEN x.Comm
				ELSE b.comm - b.playercomm
			END AS Comm,
			CASE
				WHEN @RefTable IN (1, 2) AND x.AComm IS NOT NULL THEN x.AComm
				ELSE b.acomm - b.comm
			END AS AComm,
			CASE
				WHEN @RefTable IN (1, 2) AND x.SComm IS NOT NULL THEN x.SComm
				ELSE b.scomm - b.acomm
			END AS SComm,
			CASE
				WHEN @RefTable IN (1, 2) AND x.APositiontaking IS NOT NULL THEN x.APositiontaking
				ELSE b.apositiontaking
			END AS APositionTaking,
			CASE
				WHEN @RefTable IN (1, 2) AND x.MPositionTaking IS NOT NULL THEN x.MPositionTaking
				ELSE b.mpositiontaking
			END AS MPositionTaking,
			CASE
				WHEN @RefTable IN (1, 2) AND x.SPositionTaking IS NOT NULL THEN x.SPositionTaking
				ELSE b.spositiontaking
			END AS SPositionTaking,
			CASE
				WHEN @RefTable IN (1, 2) AND x.TPositionTaking IS NOT NULL THEN x.TPositionTaking
				ELSE b.tpositiontaking
			END AS TPositionTaking,
			CASE
				WHEN b.recommend IN (-3, -4) THEN 0
				WHEN @RefTable IN (1, 2) AND x.Discount IS NOT NULL THEN x.Discount
				ELSE b.discount
			END AS ADiscount,
			CASE
				WHEN b.mrecommend = -4 THEN 0
				WHEN @RefTable IN (1, 2) AND x.ADiscount IS NOT NULL THEN x.ADiscount
				ELSE b.adiscount
			END AS MDiscount,
			CASE
				WHEN @RefTable IN (1, 2) AND x.SDiscount IS NOT NULL THEN x.SDiscount
				ELSE b.sdiscount
			END AS SDiscount,
			CASE
				WHEN b.comstatus = '1' THEN '1'
				ELSE '0'
			END AS ComStatus,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS5') THEN b.liveindicator
				ELSE 0
			END AS LiveIndicator,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'NG2', 'LG', 'VS5') THEN b.livehomescore
				ELSE 0
			END AS LiveHomeScore,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG', 'VS5') THEN b.liveawayscore
				ELSE 0
			END AS LiveAwayScore,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.hthomescore
				WHEN @Product IN ('VS5') THEN m3rd.hthomescore
				ELSE 0
			END AS HtHomeScore,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.htawayscore
				WHEN @Product IN ('VS5') THEN m3rd.htawayscore
				ELSE 0
			END AS HtAwayScore,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.finalhomescore
				WHEN @Product IN ('VS5') THEN m3rd.finalhomescore
				ELSE 0
			END AS FinalHomeScore,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.finalawayscore
				WHEN @Product IN ('VS5') THEN m3rd.finalawayscore
				ELSE 0
			END FinalAwayScore,
			b.ip,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.leagueid
				WHEN @Product IN ('Outright') THEN o.leagueid
				WHEN @Product IN ('VR') THEN vr.LeagueID
				WHEN @Product IN ('VS5') THEN m3rd.League3rdId
				WHEN @EventType = 3 THEN Vrc.leagueid
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'BTC', 'LG', 'VS4', 'VS5') THEN b.matchid
				WHEN @Product = 'NG2' THEN b.betdaqid
				WHEN @EventType = 3 THEN b.matchid
				ELSE 0
			END AS MatchId,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchcode
				WHEN @Product IN ('Outright') THEN o.matchcode
				WHEN @Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
				WHEN @Product IN ('VS5') THEN m3rd.MatchCode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN @Product IN ('Outright') THEN o.groupmatch
				WHEN @Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
				ELSE ''
			END AS Race,
			CASE
				WHEN @Product IN ('SB') THEN m.GlobalShowTime
				WHEN @Product IN ('BTC') THEN m3rd.EndTime
				ELSE b.WinLostDate
			END AS EventDate,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.homeid
				WHEN @Product IN ('Outright') THEN o.teamid
				WHEN @Product IN ('VR') THEN vo.RacerID
				WHEN @Product IN ('VS5') THEN m3rd.homeid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.awayid
				WHEN @Product IN ('VS5') THEN m3rd.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			CASE
				WHEN @Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)				
				ELSE ''
			END AS Placing,
			CASE
				WHEN @Product IN ('VS', 'VS2', 'LG', 'VS4') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN @Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN @Product IN ('SB', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT', 'ParlayVS4', 'ParlayVS5') THEN ISNULL(b.betcheck, '')
				WHEN @Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @Product IN ('SB', 'VS2', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 'VRG', 
					'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'VS3', 'NG2', 'SEA', 'LG', 'VS4', 'VS5') THEN ISNULL(b.transdesc, '')
				WHEN b.bettype = 29 AND b.OddsSpread = 3 THEN ISNULL(b.transdesc, '')
				WHEN @EventType = 3 THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betdaqid, -1)		
				ELSE -1
			END AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			'' AS JackpotInfo,
			CASE
				WHEN @Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
				ELSE ''
			END AS SiteId,
			2 AS WhTicket,
			b.DeviceType,
			le.LeagueGroupId
		FROM dbo.bettrans AS b WITH (NOLOCK)
			LEFT JOIN @TmpData AS x ON @RefTable IN (1, 2) AND @Winlostdate >= @Yesterday
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') AND b.matchid = m.matchid
			LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON @Product IN ('BTC', 'VS5') AND m3rd.Match3rdId = b.matchid
			LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
			LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON @Product IN ('VR') AND b.oddsid = vo.Orid
			LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON @Product IN ('VR') AND vr.EventID = vo.EventID
			LEFT JOIN dbo.VSRaceInfo AS vrc WITH (NOLOCK) ON @EventType = 3  AND vrc.EventID = b.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON @Product IN ('SB') AND m.leagueID = le.leagueID
		WHERE b.transid = @TransId
	END
	ELSE IF @WhTicket = 3		-- Bettrans14 range
	BEGIN
		INSERT INTO @Data (
			TransId, RefNo, CustId, Username, Currency, CurrencyId, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SettlementStatus, TransDate,
			WinLostDate, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, ComStatus,
			LiveIndicator, LiveHomeScore, LiveAwayScore, HtHomeScore, HtAwayScore, FinalHomeScore, FinalAwayScore, Ip, LeagueId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral, Placing,
			ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, SiteId, WhTicket, DeviceType, LeagueGroupId
		)
		SELECT
			b14.transid,
			b14.refno,
			b14.custid,
			b14.Username,
			b14.CurrencyName AS Currency,
			b14.currency AS CurrencyId,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'VB', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SPR', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 
					'SAG', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 
					'BBIN', 'RNGW', 'SEA', 'IBCLC', 'ION', 'PPL', 'L22', 'WE') THEN b14.matchid
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.sporttype
				WHEN @Product IN ('BTC', 'VS5') THEN m3rd.SportType
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @Product IN ('VR') THEN vr.SportType
				WHEN @Product = 'NG2' AND b14.bettype BETWEEN 2501 AND 2539 THEN 213
				WHEN @Product = 'NG2' AND b14.bettype BETWEEN 2541 AND 2579 THEN 214
				WHEN @Product = 'NG2' AND b14.bettype BETWEEN 2581 AND 2619 THEN 215
				WHEN @Product = 'NG2' AND b14.bettype BETWEEN 2621 AND 2659 THEN 216
				WHEN @Product = 'NG2' AND b14.bettype BETWEEN 2681 AND 2699 THEN 218
				WHEN @RefTable IN (1, 2) THEN b14.matchid
				WHEN @EventType = 3 THEN vrc.sporttype
				ELSE 0
			END AS SportType,
			b14.bettype,
			ISNULL(b14.betid, 0) AS BetId,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5') THEN b14.betteam
				WHEN @EventType = 3 THEN b14.betteam
				ELSE ''
			END AS BetTeam,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'BTC', 'NG2', 'LG', 'ParlayVS4', 'VS5', 'ParlayVS5') THEN b14.hdp1
				ELSE 0
			END AS Hdp1,
			CASE
				WHEN @Product IN ('SB', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2', 'LG', 'ParlayVS4', 'VS5', 'ParlayVS5') THEN b14.hdp2
				ELSE 0
			END AS Hdp2,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG', 'VS4', 'VS5') THEN b14.oddstype
				WHEN @EventType = 3 THEN b14.oddstype
				ELSE 0
			END AS OddsType,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'Keno', 'ParlayVS2', 'Lottery', 
					'OneRNG', 'VRG', 'TG', 'I4D', 'PP', 'SBC', 'SLT', 'VGA', 'H5LG', 'SG', 'VS3', 'BTC', 'NG2', 'LG', 'VS4', 'VS5') THEN b14.odds
				WHEN @EventType = 3 THEN b14.odds
				ELSE 0
			END AS Odds,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5') THEN b14.modds
				WHEN @EventType = 3 THEN b14.modds
				ELSE 0
			END AS MOdds,
			CASE
				WHEN @Product IN ('SB', 'PP', 'SBC', 'VGA', 'SG', 'Parlay') THEN ISNULL(b14.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			b14.stake,
			b14.actual_stake,
			CASE
				WHEN @Product = 'TG' AND b14.status = 'Won' AND b14.modds = 0.25 THEN 'Half Won'
				WHEN @Product = 'TG' AND b14.status = 'Lose' AND b14.modds = -0.25 THEN 'Half Lose'
				ELSE b14.status
			END AS Status,
			0 AS SettlementStatus,
			b14.transdate,
			b14.winlostdate,
			b14.winlost - b14.actual_stake AS WinLost,
			b14.awinlost,
			b14.mwinlost,
			b14.swinlost,
			b14.playercomm,
			b14.comm - b14.playercomm AS Comm,
			b14.acomm - b14.comm AS AComm,
			b14.scomm - b14.acomm AS SComm,
			b14.apositiontaking,
			b14.mpositiontaking,
			b14.spositiontaking,
			b14.tpositiontaking,
			CASE
				WHEN b14.recommend IN (-3, -4) THEN 0
				ELSE b14.discount
			END	AS ADiscount,
			CASE
				WHEN b14.mrecommend = -4 THEN 0
				ELSE b14.adiscount
			END AS MDiscount,
			b14.sdiscount,
			CASE
				WHEN b14.comstatus = '1' THEN '1'
				ELSE '0'
			END AS ComStatus,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS5') THEN b14.liveindicator
				ELSE 0
			END AS LiveIndicator,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'NG2', 'LG', 'VS5') THEN b14.livehomescore
				ELSE 0
			END AS LiveHomeScore,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG', 'VS5') THEN b14.liveawayscore
				ELSE 0
			END AS LiveAwayScore,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.hthomescore
				WHEN @Product IN ('VS5') THEN m3rd.hthomescore
				ELSE 0
			END AS HtHomeScore,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.htawayscore
				WHEN @Product IN ('VS5') THEN m3rd.htawayscore
				ELSE 0
			END AS HtAwayScore,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.finalhomescore
				WHEN @Product IN ('VS5') THEN m3rd.finalhomescore
				ELSE 0
			END AS FinalHomeScore,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.finalawayscore
				WHEN @Product IN ('VS5') THEN m3rd.finalawayscore
				ELSE 0
			END FinalAwayScore,
			b14.ip,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.leagueid
				WHEN @Product IN ('Outright') THEN o.leagueid
				WHEN @Product IN ('VR') THEN vr.LeagueID
				WHEN @Product IN ('VS5') THEN m3rd.League3rdId
				WHEN @EventType = 3 THEN vrc.LeagueId
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'BTC', 'LG', 'VS4', 'VS5') THEN b14.matchid
				WHEN @Product = 'NG2' THEN b14.betdaqid
				WHEN @EventType = 3 THEN b14.matchid
				ELSE 0
			END AS MatchId,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchcode
				WHEN @Product IN ('Outright') THEN o.matchcode
				WHEN @Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
				WHEN @Product IN ('VS5') THEn m3rd.MatchCode				
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN @Product IN ('Outright') THEN o.groupmatch
				WHEN @Product IN ('VR') THEN CONVERT(NVARCHAR(50), b14.oddsid)
				ELSE ''
			END AS Race,
			CASE
				WHEN @Product IN ('SB') THEN m.GlobalShowTime
				WHEN @Product IN ('BTC') THEN m3rd.EndTime
				ELSE b14.WinLostDate
			END AS EventDate,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.homeid
				WHEN @Product IN ('Outright') THEN o.teamid
				WHEN @Product IN ('VR') THEN vo.RacerID
				WHEN @Product IN ('VS5') THEN m3rd.homeid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.awayid
				WHEN @Product IN ('VS5') THEN m3rd.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			CASE
				WHEN @Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
				ELSE ''
			END AS Placing,
			CASE
				WHEN @Product IN ('VS', 'VS2', 'LG') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN @Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN @Product IN ('SB', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT', 'ParlayVS4', 'ParlayVS5') THEN ISNULL(b14.betcheck, '')
				WHEN @Product IN ('Keno') THEN ISNULL(b14.ComStatus, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @Product IN ('SB', 'VS2', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'PP', 'VRG', 
					'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'VS3', 'NG2', 'SEA', 'LG', 'VS4', 'VS5') THEN ISNULL(b14.transdesc, '')
				WHEN b14.bettype = 29 AND b14.OddsSpread = 3 THEN ISNULL(b14.transdesc, '')
				WHEN @EventType = 3 THEN ISNULL(b14.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b14.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
			'' AS JackpotInfo,
			CASE
				WHEN @Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b14.BetdaqId)
				ELSE ''
			END AS SiteId,
			3 AS WhTicket,
			b14.DeviceType,
			le.LeagueGroupId
		FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
			LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON @Product IN ('SB', 'NG', 'VS', 'VS2', 'LG', 'VS4') AND b14.matchid = m.matchid
			LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON @Product IN ('BTC', 'VS5') AND m3rd.Match3rdId = b14.matchid
			LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b14.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
			LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON @Product IN ('VR') AND b14.oddsid = vo.Orid
			LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON @Product IN ('VR') AND vr.EventID = vo.EventID
			LEFT JOIN dbo.VSRaceInfo14 AS vrc WITH (NOLOCK) ON @EventType = 3  AND vrc.EventID = b14.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON @Product IN ('SB') AND m.leagueID = le.leagueID
		WHERE b14.transid = @TransId
	END

	-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
	IF EXISTS (SELECT 1 FROM @Data
				WHERE BetType = 29
					AND BetTeam = '1'
					AND WhTicket IN (2, 3))
	BEGIN
		-- Running/Waiting
		DECLARE @ParlayData TABLE (
			RefNo		BIGINT,
			BoostRate	MONEY)

		INSERT INTO @ParlayData (RefNo, BoostRate)
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
		INSERT INTO @TmpParlayData (RefNo, Odds, MOdds)
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
		INSERT INTO @TmpParlayData (RefNo, Odds, MOdds)
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
			AND WhTicket IN (2, 3)
			AND b.Status NOT IN ('Running', 'Waiting')
	END

	-- BettransRnG tables
	SET @ProductId = 0
	SET @MemberUplineId = 0

	-- BettransRnG range
	IF @WhTicket = 0
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@MemberUplineId = CASE @RoleId
									WHEN 2 THEN b.recommend
									WHEN 3 THEN b.mrecommend
									WHEN 4 THEN b.srecommend
									ELSE 0
								END,
			@CustId = b.custid,
			@WinLostDate = b.winlostdate,
			@ProductId = s.ProductID,
			@EventType = s.EventType,
			@WhTicket = 5		-- BettransRnG
		FROM dbo.bettransRnG AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON 
			s.bettype = b.gameID
		WHERE b.transid = @RefNo 
		AND s.RefTable = 1
		AND b.winlostdate > @MoveBetsDay
	END

	-- BettransRnG14 range
	IF @WhTicket = 0 OR @UplineId <> @MemberUplineId
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@MemberUplineId = CASE @RoleId
								WHEN 2 THEN b.recommend
								WHEN 3 THEN b.mrecommend
								WHEN 4 THEN b.srecommend
								ELSE 0
							END,
			@CustId = b.custid,
			@WinLostDate = b.winlostdate,
			@ProductId = s.ProductID,
			@EventType = s.EventType,
			@WhTicket = 6		-- BettransRnG14
		FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.bettype = b.gameID
		WHERE b.transid = @RefNo
			AND s.RefTable = 1
			AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
	END

	-- Check belonging
	IF @UplineId <> @MemberUplineId
		SET @WhTicket = 0

	SET @Product = CASE
						WHEN @ProductId = 6 THEN 'OneRNG'		-- RNG Casino
						WHEN @ProductId = 22 THEN 'VB'			-- Macau Games
						WHEN @ProductId = 32 THEN 'PP'			-- Pragmatic Play Casino
						WHEN @ProductId = 34 THEN 'CC'			-- Card Club
						WHEN @ProductId = 36 THEN 'SG'			-- Spadegaming
						WHEN @ProductId = 42 THEN 'SBC'			-- Saba.club
						WHEN @ProductId = 50 THEN 'RNGW'		-- RNG War
						WHEN @ProductId = 55 THEN 'PGS'			-- PG Soft
						WHEN @ProductId = 56 THEN 'JK'			-- Joker
						WHEN @ProductId = 60 THEN 'MXG'			-- MaxGame
						WHEN @ProductId = 61 THEN 'HB'			-- Habanero
						WHEN @ProductId = 62 THEN 'CG'			-- CG
						WHEN @ProductId = 66 THEN 'VGA'			-- Vgaming
						WHEN @ProductId = 67 THEN 'AP'			-- AdvantPlay
						WHEN @ProductId = 68 THEN 'APM'			-- AdvantPlay Mini
						WHEN @ProductId = 72 THEN 'SEA'			-- SEAL Entertainment
						WHEN @ProductId = 73 THEN 'MGRNG'		-- MG-RNG
						WHEN @ProductId = 75 THEN 'JIG'			-- Jili
						WHEN @ProductID = 78 THEN 'UUSL'		-- UU Slots
						WHEN @ProductId = 79 THEN 'L22'			-- Live22
						WHEN @ProductId = 84 THEN 'GPILT'		-- GPI Lottery
						WHEN @ProductId = 85 THEN 'NS'			-- Nextspin
						WHEN @ProductId = 86 THEN 'SNG'			-- Saba xD
						WHEN @ProductId = 87 THEN 'FS'			-- FastSpin
						WHEN @ProductId = 89 THEN 'FAC'			-- FA CHAI
						WHEN @ProductId = 100 THEN 'PTRNG'		-- Playtech
						WHEN @ProductId = 48 THEN 'GPIRNG'		-- GPI
						WHEN @ProductId = 91 THEN 'PS'			-- PLAY STAR
						WHEN @ProductId = 95 THEN 'HOT'			-- HOTDOG						
						WHEN @ProductId = 102 THEN 'SBK'		-- SABA Keno
						WHEN @ProductId = 103 THEN 'ASK'		-- ASKMESLOT
						WHEN @ProductId = 104 THEN 'FG'			-- Funky Games
						WHEN @ProductId = 105 THEN 'ODG'		-- ODIN GAMING
						WHEN @ProductId = 108 THEN 'RGRNG'		-- Rich Gaming
						WHEN @ProductID = 109 THEN 'CPRNG'		-- ClotPlay
						WHEN @ProductID = 110 THEN 'AIG'		-- AI Gaming
						ELSE 'Unknown'
					END

	
		-- BettransRnG
		IF @WhTicket = 5
		BEGIN
			INSERT INTO @Data (
				TransId, RefNo, CustId, Username, Currency, CurrencyId, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SettlementStatus, TransDate,
				WinLostDate, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, ComStatus,
				LiveIndicator, LiveHomeScore, LiveAwayScore, HtHomeScore, HtAwayScore, FinalHomeScore, FinalAwayScore, Ip, LeagueId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral, Placing,
				ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, SiteId, WhTicket, DeviceType, LeagueGroupId
			)
			SELECT
				transid,
				transid AS RefNo,
				custid,
				Username,
				CurrencyName AS Currency,
				currency AS CurrencyId,
				productID AS SportType,
				gameID AS BetType,
				0 AS BetId,
				ISNULL(GameId3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				CASE
					WHEN @Product IN ('OneRNG', 'PP', 'SG') AND statusID IN (111, 112, 113) THEN ISNULL(ContributionRate, 0)
					ELSE odds
				END AS Odds,
				0 AS MOdds,
				CASE
					WHEN @Product IN ('OneRNG', 'PP', 'SG') AND statusID IN (111, 112, 113) THEN ISNULL(BetStake, 0)
					ELSE 0
				END AS OddsSpread,
				stake,
				actual_stake,
				status,
				0 AS SettlementStatus,
				transdate,
				winlostdate,
				winlost - actual_stake AS WinLost,
				awinlost,
				mwinlost,
				swinlost,
				playercomm,
				comm - playercomm AS Comm,
				acomm - comm AS AComm,
				scomm - acomm AS SComm,
				apositiontaking,
				mpositiontaking,
				spositiontaking,
				tpositiontaking,
				CASE
					WHEN recommend IN (-3, -4) THEN 0
					ELSE discount
				END AS ADiscount,
				CASE
					WHEN mrecommend = -4 THEN 0
					ELSE adiscount
				END AS MDiscount,
				sdiscount,
				'0' AS ComStatus,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				ip,
				0 AS LeagueId,
				0 AS MatchId,
				CASE
					WHEN @Product IN ('PP', 'CC', 'VGA') THEN Additional
					WHEN @Product IN ('SBC') THEN ISNULL(SiteID, '')
					ELSE ''
				END AS MatchCode,
				'' AS Race,
				TransDate3rd AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				TranId3rd AS BetCheck,
				transdesc,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				ExtraInfo,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
				ISNULL(SiteID, '') AS SiteId,
				5 AS WhTicket,
				DeviceType,
				0 AS LeagueGroupId
			FROM dbo.bettransRnG WITH (NOLOCK)
			WHERE transid = @TransId
		END

		-- BettransRnG14
		IF @WhTicket = 6
		BEGIN
			INSERT INTO @Data (
				TransId, RefNo, CustId, Username, Currency, CurrencyId, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SettlementStatus, TransDate,
				WinLostDate, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, ComStatus,
				LiveIndicator, LiveHomeScore, LiveAwayScore, HtHomeScore, HtAwayScore, FinalHomeScore, FinalAwayScore, Ip, LeagueId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral, Placing,
				ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, SiteId, WhTicket, DeviceType, LeagueGroupId
			)
			SELECT
				transid,
				transid AS RefNo,
				custid,
				Username,
				CurrencyName AS Currency,
				currency AS CurrencyId,
				productID AS SportType,
				gameID AS BetType,
				0 AS BetId,
				ISNULL(GameId3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				CASE
					WHEN @Product IN ('OneRNG', 'PP', 'SG') AND statusID IN (111, 112, 113) THEN ISNULL(ContributionRate, 0)
					ELSE odds
				END AS Odds,
				0 AS MOdds,
				CASE
					WHEN @Product IN ('OneRNG', 'PP', 'SG') AND statusID IN (111, 112, 113) THEN ISNULL(BetStake, 0)
					ELSE 0
				END AS OddsSpread,
				stake,
				actual_stake,
				status,
				0 AS SettlementStatus,
				transdate,
				winlostdate,
				winlost - actual_stake AS WinLost,
				awinlost,
				mwinlost,
				swinlost,
				playercomm,
				comm - playercomm AS Comm,
				acomm - comm AS AComm,
				scomm - acomm AS SComm,
				apositiontaking,
				mpositiontaking,
				spositiontaking,
				tpositiontaking,
				CASE
					WHEN recommend IN (-3, -4) THEN 0
					ELSE discount
				END AS ADiscount,
				CASE
					WHEN mrecommend = -4 THEN 0
					ELSE adiscount
				END AS MDiscount,
				sdiscount,
				'0' AS ComStatus,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				ip,
				0 AS LeagueId,
				0 AS MatchId,
				CASE
					WHEN @Product IN ('PP', 'CC', 'VGA') THEN Additional
					WHEN @Product IN ('SBC') THEN ISNULL(SiteID, '')
					ELSE ''
				END AS MatchCode,
				'' AS Race,
				TransDate3rd AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				TranId3rd AS BetCheck,
				transdesc,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				ExtraInfo,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
				ISNULL(SiteID, '') AS SiteId,
				6 AS WhTicket,
				DeviceType,
				0 AS LeagueGroupId
			FROM dbo.bettransRnG14 WITH (NOLOCK)
			WHERE transid = @TransId
		END
	

	-- BettransLC tables
	SET @ProductId = 0
	SET @MemberUplineId = 0

	-- BettransLC range
	IF @WhTicket = 0
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@MemberUplineId = CASE @RoleId
									WHEN 2 THEN b.recommend
									WHEN 3 THEN b.mrecommend
									WHEN 4 THEN b.srecommend
									ELSE 0
								END,
			@CustId = b.custid,
			@WinLostDate = b.winlostdate,
			@ProductId = s.ProductID,
			@EventType = s.EventType,
			@WhTicket = 8		-- bettransLC
		FROM dbo.bettransLC AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.bettype = b.gameID
		WHERE b.transid = @RefNo AND s.RefTable = 2 AND b.winlostdate > @MoveBetsDay
	END

	-- BettransLC14 range
	IF @WhTicket = 0 OR @UplineId <> @MemberUplineId
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@MemberUplineId = CASE @RoleId
								WHEN 2 THEN b.recommend
								WHEN 3 THEN b.mrecommend
								WHEN 4 THEN b.srecommend
								ELSE 0
							END,
			@CustId = b.custid,
			@WinLostDate = b.winlostdate,
			@ProductId = s.ProductID,
			@EventType = s.EventType,
			@WhTicket = 9		-- bettransLC14
		FROM dbo.bettransLC14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.bettype = b.gameID
		WHERE b.transid = @RefNo
			AND s.RefTable = 2
			AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
	END

	-- Check belonging
	IF @UplineId <> @MemberUplineId
		SET @WhTicket = 0

	SET @Product = CASE
						WHEN @ProductId = 21 THEN 'AllBet'
						WHEN @ProductId = 39 THEN 'SAG'
						WHEN @ProductId = 45 THEN 'SXG'
						WHEN @ProductId = 46 THEN 'IBCLC'		-- IBCBet Live Casino
						WHEN @ProductId = 51 THEN 'WM'
						WHEN @ProductId = 52 THEN 'ION'
						WHEN @ProductId = 57 THEN 'BG'
						WHEN @ProductId = 65 THEN 'PPL'			-- PP Live Casino
						WHEN @ProductId = 70 THEN 'FGGL'
						WHEN @ProductId = 76 THEN 'YB'
						WHEN @ProductId = 80 THEN 'WE'
						WHEN @ProductId = 96 THEN 'ON'
						WHEN @ProductID = 98 THEN 'WLC'			-- W Casino
						WHEN @ProductId = 90 THEN 'GPILC'
						WHEN @ProductID = 101 THEN 'PTLC'		-- Playtech Live Casino
						WHEN @ProductId = 107 THEN 'MGLC' 		-- Microgaming Live						
						ELSE 'Unknown'
					END

		-- BettransLC
		IF @WhTicket = 8
		BEGIN
			INSERT INTO @Data (
				TransId, RefNo, CustId, Username, Currency, CurrencyId, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SettlementStatus, TransDate,
				WinLostDate, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, ComStatus,
				LiveIndicator, LiveHomeScore, LiveAwayScore, HtHomeScore, HtAwayScore, FinalHomeScore, FinalAwayScore, Ip, LeagueId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral, Placing,
				ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, SiteId, WhTicket, DeviceType, LeagueGroupId
			)
			SELECT
				transid,
				transid AS RefNo,
				custid,
				Username,
				CurrencyName AS Currency,
				currency AS CurrencyId,
				productID AS SportType,
				gameID AS BetType,
				0 AS BetId,
				'' AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				odds,
				0 AS MOdds,
				0 AS OddsSpread,
				stake,
				actual_stake,
				status,
				0 AS SettlementStatus,
				transdate,
				winlostdate,
				winlost - actual_stake AS WinLost,
				awinlost,
				mwinlost,
				swinlost,
				playercomm,
				comm - playercomm AS Comm,
				acomm - comm AS AComm,
				scomm - acomm AS SComm,
				apositiontaking,
				mpositiontaking,
				spositiontaking,
				tpositiontaking,
				CASE
					WHEN recommend IN (-3, -4) THEN 0
					ELSE discount
				END AS ADiscount,
				CASE
					WHEN mrecommend = -4 THEN 0
					ELSE adiscount
				END	AS MDiscount,
				sdiscount,
				'0' AS ComStatus,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS HtHomeScore,
				0 AS HtAwayScore,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				ip,
				currency AS LeagueId,
				0 AS MatchId,
				GameId3rd AS MatchCode,
				'' AS Race,
				TransDate3rd AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				TranId3rd AS BetCheck,
				transdesc,
				-1 AS BetdaqId,
				ExtraInfo,
				'' AS JackpotInfo,
				SiteID,
				8 AS WhTicket,
				DeviceType,
				0 AS LeagueGroupId
			FROM dbo.bettransLC WITH (NOLOCK)
			WHERE transid = @TransId
		END

		-- BettransLC14
		IF @WhTicket = 9
		BEGIN
			-- BettransLC14
			IF @WhTicket = 9
			BEGIN
				INSERT INTO @Data (
					TransId, RefNo, CustId, Username, Currency, CurrencyId, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SettlementStatus, TransDate,
					WinLostDate, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, ComStatus,
					LiveIndicator, LiveHomeScore, LiveAwayScore, HtHomeScore, HtAwayScore, FinalHomeScore, FinalAwayScore, Ip, LeagueId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral, Placing,
					ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, SiteId, WhTicket, DeviceType, LeagueGroupId
				)
				SELECT
					transid AS TransId_lc14,
					transid AS RefNo_lc14,
					custid AS CustId_lc14,
					Username AS Username_lc14,
					CurrencyName AS Currency_lc14,
					currency AS CurrencyId_lc14,
					productID AS SportType_lc14,
					gameID AS BetType_lc14,
					0 AS BetId_lc14,
					'' AS BetTeam_lc14,
					0 AS Hdp1_lc14,
					0 AS Hdp2_lc14,
					0 AS OddsType_lc14,
					odds AS Odds_lc14,
					0 AS MOdds_lc14,
					0 AS OddsSpread_lc14,
					stake AS Stake_lc14,
					actual_stake AS Actual_Stake_lc14,
					status AS Status_lc14,
					0 AS SettlementStatus_lc14,
					transdate AS TransDate_lc14,
					winlostdate AS WinLostDate_lc14,
					winlost - actual_stake AS WinLost_lc14,
					awinlost AS AWinLost_lc14,
					mwinlost AS MWinLost_lc14,
					swinlost AS SWinLost_lc14,
					playercomm AS PlayerComm_lc14,
					comm - playercomm AS Comm_lc14,
					acomm - comm AS AComm_lc14,
					scomm - acomm AS SComm_lc14,
					apositiontaking AS APositiontaking_lc14,
					mpositiontaking AS MPositiontaking_lc14,
					spositiontaking AS SPositiontaking_lc14,
					tpositiontaking AS TPositiontaking_lc14,
					CASE
						WHEN recommend IN (-3, -4) THEN 0
						ELSE discount
					END AS ADiscount_lc14,
					CASE
						WHEN mrecommend = -4 THEN 0
						ELSE adiscount
					END AS MDiscount_lc14,
					sdiscount AS SDiscount_lc14,
					'0' AS ComStatus_lc14,
					0 AS LiveIndicator_lc14,
					0 AS LiveHomeScore_lc14,
					0 AS LiveAwayScore_lc14,
					0 AS HtHomeScore_lc14,
					0 AS HtAwayScore_lc14,
					0 AS FinalHomeScore_lc14,
					0 AS FinalAwayScore_lc14,
					ip AS Ip_lc14,
					currency AS LeagueId_lc14,
					0 AS MatchId_lc14,
					GameId3rd AS MatchCode_lc14,
					'' AS Race_lc14,
					TransDate3rd AS EventDate_lc14,
					0 AS HomeId_lc14,
					0 AS AwayId_lc14,
					'' AS BetStatus_lc14,
					0 AS IsNeutral_lc14,
					'' AS Placing_lc14,
					'' AS ShowTime_lc14,
					TranId3rd AS BetCheck_lc14,
					transdesc AS TransDesc_lc14,
					-1 AS BetdaqId_lc14,
					ExtraInfo AS ExtraInfo_lc14,
					'' AS JackpotInfo_lc14,
					SiteID AS SiteId_lc14,
					9 AS WhTicket_lc14,
					DeviceType AS DeviceType_lc14,
					0 AS LeagueGroupId_lc14
				FROM dbo.bettransLC14 WITH (NOLOCK)
				WHERE transid = @TransId
			END
		END
	

	-- Bettransg tables
	SET @ProductId = 0
	SET @MemberUplineId = 0

	-- Bettransg range
	IF @WhTicket = 0
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@MemberUplineId = CASE s.ProductID
								WHEN 39 THEN CASE @RoleId
												WHEN 2 THEN blc.recommend
												WHEN 3 THEN blc.mrecommend
												WHEN 4 THEN blc.srecommend
												ELSE 0
											END
								WHEN 47 THEN CASE @RoleId
												WHEN 2 THEN bt.recommend
												WHEN 3 THEN bt.mrecommend
												WHEN 4 THEN bt.srecommend
												ELSE 0
											END
								ELSE 0
							END,
			@CustId = b.custid,
			@WinLostDate = b.winlostdate,
			@ProductId = s.ProductID,
			@EventType = s.EventType,
			@WhTicket = 11		-- bettransg
		FROM dbo.bettransg AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.bettype = b.bettype
			LEFT JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.transid = b.refno AND blc.custid = b.custid AND s.ProductID = 39
			LEFT JOIN dbo.bettrans AS bt WITH (NOLOCK) ON bt.transid = b.refno AND bt.custid = b.CustId AND s.ProductID = 47
		WHERE b.transid = @RefNo AND b.winlostdate > @MoveBetsDay
	END

	-- Bettransg14 range
	IF @WhTicket = 0 OR @UplineId <> @MemberUplineId
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@MemberUplineId = CASE s.ProductID
								WHEN 39 THEN CASE @RoleId
												WHEN 2 THEN blc.recommend
												WHEN 3 THEN blc.mrecommend
												WHEN 4 THEN blc.srecommend
												ELSE 0
											END
								WHEN 47 THEN CASE @RoleId
												WHEN 2 THEN bt.recommend
												WHEN 3 THEN bt.mrecommend
												WHEN 4 THEN bt.srecommend
												ELSE 0
											END
								ELSE 0
							END,
			@CustId = b.custid,
			@WinLostDate = b.winlostdate,
			@ProductId = s.ProductID,
			@EventType = s.EventType,
			@WhTicket = 12		-- bettransg14
		FROM dbo.bettransg14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.bettype = b.bettype
			LEFT JOIN dbo.bettransLC14 AS blc WITH (NOLOCK) ON blc.transid = b.refno AND blc.custid = b.custid AND s.ProductID = 39
			LEFT JOIN dbo.bettrans14 AS bt WITH (NOLOCK) ON bt.transid = b.refno AND bt.custid = b.CustId AND s.ProductID = 47
		WHERE b.transid = @RefNo
			AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
	END

	-- Check belonging
	IF @UplineId <> @MemberUplineId
		SET @WhTicket = 0

	SET @Product = CASE
						WHEN @ProductId = 39 THEN 'SAG'
						WHEN @ProductId = 47 THEN 'BBIN'
						ELSE 'Unknown'
					END

	IF @Product <> 'Unknown'
	BEGIN
		-- Bettransg
		IF @WhTicket = 11
		BEGIN
			-- SA Gaming
			IF @ProductId = 39
			BEGIN
				INSERT INTO @Data (
									TransId, RefNo, CustId, Username, Currency, CurrencyId, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SettlementStatus, TransDate,
									WinLostDate, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, ComStatus,
									LiveIndicator, LiveHomeScore, LiveAwayScore, HtHomeScore, HtAwayScore, FinalHomeScore, FinalAwayScore, Ip, LeagueId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral, Placing,
									ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, SiteId, WhTicket, DeviceType, LeagueGroupId
				)
				SELECT
					sag.transid,
					blc.transid AS RefNo,
					sag.custid,
					blc.Username,
					blc.CurrencyName AS Currency,
					blc.currency AS CurrencyId,
					blc.productID AS SportType,
					blc.gameID AS BetType,
					0 AS BetId,
					ISNULL(sag.BetID3rd, '') AS BetTeam,
					0 AS Hdp1,
					0 AS Hdp2,
					0 AS OddsType,
					sag.odds,
					0 AS MOdds,
					0 AS OddsSpread,
					sag.stake,
					sag.actual_stake,
					sag.status,
					0 AS SettlementStatus,
					sag.transdate,
					sag.winlostdate,
					sag.winlost - sag.actual_stake AS WinLost,
					sag.awinlost,
					sag.mwinlost,
					sag.swinlost,
					sag.playercomm,
					sag.comm - sag.playercomm AS Comm,
					sag.acomm - sag.comm AS AComm,
					sag.scomm - sag.acomm AS SComm,
					sag.apositiontaking,
					sag.mpositiontaking,
					sag.spositiontaking,
					sag.tpositiontaking,
					CASE
						WHEN recommend IN (-3, -4) THEN 0
						ELSE sag.discount
					END AS ADiscount,
					CASE
						WHEN mrecommend = -4 THEN 0
						ELSE sag.adiscount
					END AS MDiscount,
					sag.sdiscount,
					'0' AS ComStatus,
					0 AS LiveIndicator,
					0 AS LiveHomeScore,
					0 AS LiveAwayScore,
					0 AS HtHomeScore,
					0 AS HtAwayScore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					blc.ip,
					0 AS LeagueId,
					0 AS MatchId,
					blc.GameId3rd AS MatchCode,
					'' AS Race,
					NULL AS EventDate,
					0 AS HomeId,
					0 AS AwayId,
					'' AS BetStatus,
					0 AS IsNeutral,
					'' AS Placing,
					'' AS ShowTime,
					ISNULL(sag.TransDesc, '') AS BetCheck,
					blc.transdesc,
					-1 AS BetdaqId,
					sag.ExtraInfo,
					'' AS JackpotInfo,
					blc.SiteID,
					11 AS WhTicket,
					sag.DeviceType,
					0 AS LeagueGroupId
				FROM dbo.bettransg AS sag WITH (NOLOCK)
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.transid = sag.refno AND blc.custid = sag.custid
				WHERE sag.transid = @TransId
			END

			-- BBIN
			IF @ProductId = 47
			BEGIN
				INSERT INTO @Data (
					TransId, RefNo, CustId, Username, Currency, CurrencyId, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SettlementStatus, TransDate,
					WinLostDate, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, ComStatus,
					LiveIndicator, LiveHomeScore, LiveAwayScore, HtHomeScore, HtAwayScore, FinalHomeScore, FinalAwayScore, Ip, LeagueId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral, Placing,
					ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, SiteId, WhTicket, DeviceType, LeagueGroupId
				)
				SELECT
					b.transid,
					b.transid AS RefNo,
					b.custid,
					b2.Username,
					b2.CurrencyName AS Currency,
					b2.currency AS CurrencyId,
					b.matchid AS SportType,
					b.bettype,
					0 AS BetId,
					ISNULL(b.betteam, '') AS BetTeam,
					0 AS Hdp1,
					0 AS Hdp2,
					0 AS OddsType,
					b.odds,
					0 AS MOdds,
					0 AS OddsSpread,
					b.stake,
					b.actual_stake,
					b.status,
					0 AS SettlementStatus,
					b.transdate,
					b.winlostdate,
					b.winlost - b.actual_stake AS WinLost,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					b.playercomm,
					b.comm - b.playercomm AS Comm,
					b.acomm - b.comm AS AComm,
					b.scomm - b.acomm AS SComm,
					b.apositiontaking,
					b.mpositiontaking,
					b.spositiontaking,
					b.tpositiontaking,
					CASE
						WHEN recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END AS ADiscount,
					CASE
						WHEN mrecommend = -4 THEN 0
						ELSE b.adiscount
					END AS MDiscount,
					b.sdiscount,
					'0' AS ComStatus,
					0 AS LiveIndicator,
					0 AS LiveHomeScore,
					0 AS LiveAwayScore,
					0 AS HtHomeScore,
					0 AS HtAwayScore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					b2.ip,
					0 AS LeagueId,
					0 AS MatchId,
					'' AS MatchCode,
					'' AS Race,
					NULL AS EventDate,
					0 AS HomeId,
					0 AS AwayId,
					'' AS BetStatus,
					0 AS IsNeutral,
					'' AS Placing,
					'' AS ShowTime,
					ISNULL(b.BetID3rd, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					-1 AS BetdaqId,
					b.ExtraInfo,
					'' AS JackpotInfo,
					b.SiteId,
					11 AS WhTicket,
					b.DeviceType,
					0 AS LeagueGroupId
				FROM dbo.bettransg AS b WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
				WHERE b.transid = @TransId
			END
		END

		-- Bettransg14
		IF @WhTicket = 12
		BEGIN
			-- SA Gaming
			IF @ProductId = 39
			BEGIN
				INSERT INTO @Data (
					TransId, RefNo, CustId, Username, Currency, CurrencyId, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SettlementStatus, TransDate,
					WinLostDate, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, ComStatus,
					LiveIndicator, LiveHomeScore, LiveAwayScore, HtHomeScore, HtAwayScore, FinalHomeScore, FinalAwayScore, Ip, LeagueId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral, Placing,
					ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, SiteId, WhTicket, DeviceType, LeagueGroupId
				)
				SELECT
					sag14.transid,
					blc.transid AS RefNo,
					sag14.custid,
					blc.Username,
					blc.CurrencyName AS Currency,
					blc.currency AS CurrencyId,
					blc.productID AS SportType,
					blc.gameID AS BetType,
					0 AS BetId,
					ISNULL(sag14.BetID3rd, '') AS BetTeam,
					0 AS Hdp1,
					0 AS Hdp2,
					0 AS OddsType,
					sag14.odds,
					0 AS MOdds,
					0 AS OddsSpread,
					sag14.stake,
					sag14.actual_stake,
					sag14.status,
					0 AS SettlementStatus,
					sag14.transdate,
					sag14.winlostdate,
					sag14.winlost - sag14.actual_stake AS WinLost,
					sag14.awinlost,
					sag14.mwinlost,
					sag14.swinlost,
					sag14.playercomm,
					sag14.comm - sag14.playercomm AS Comm,
					sag14.acomm - sag14.comm AS AComm,
					sag14.scomm - sag14.acomm AS SComm,
					sag14.apositiontaking,
					sag14.mpositiontaking,
					sag14.spositiontaking,
					sag14.tpositiontaking,
					CASE
						WHEN recommend IN (-3, -4) THEN 0
						ELSE sag14.discount
					END AS ADiscount,
					CASE
						WHEN mrecommend = -4 THEN 0
						ELSE sag14.adiscount
					END AS MDiscount,
					sag14.sdiscount,
					'0' AS ComStatus,
					0 AS LiveIndicator,
					0 AS LiveHomeScore,
					0 AS LiveAwayScore,
					0 AS HtHomeScore,
					0 AS HtAwayScore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					blc.ip,
					0 AS LeagueId,
					0 AS MatchId,
					blc.GameId3rd AS MatchCode,
					'' AS Race,
					NULL AS EventDate,
					0 AS HomeId,
					0 AS AwayId,
					'' AS BetStatus,
					0 AS IsNeutral,
					'' AS Placing,
					'' AS ShowTime,
					ISNULL(sag14.TransDesc, '') AS BetCheck,
					blc.transdesc,
					-1 AS BetdaqId,
					sag14.ExtraInfo,
					'' AS JackpotInfo,
					blc.SiteID,
					12 AS WhTicket,
					sag14.DeviceType,
					0 AS LeagueGroupId
				FROM dbo.bettransg14 AS sag14 WITH (NOLOCK)
					INNER JOIN dbo.bettransLC14 AS blc WITH (NOLOCK) ON blc.transid = sag14.refno AND blc.custid = sag14.custid
				WHERE sag14.transid = @TransId
			END

			-- BBIN
			IF @ProductId = 47
			BEGIN
				INSERT INTO @Data (
					TransId, RefNo, CustId, Username, Currency, CurrencyId, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SettlementStatus, TransDate,
					WinLostDate, WinLost, AWinLost, MWinLost, SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, ComStatus,
					LiveIndicator, LiveHomeScore, LiveAwayScore, HtHomeScore, HtAwayScore, FinalHomeScore, FinalAwayScore, Ip, LeagueId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral, Placing,
					ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, SiteId, WhTicket, DeviceType, LeagueGroupId
				)
				SELECT
					b14.transid,
					b14.transid AS RefNo,
					b14.custid,
					b2.Username,
					b2.CurrencyName AS Currency,
					b2.currency AS CurrencyId,
					b14.matchid AS SportType,
					b14.bettype,
					0 AS BetId,
					ISNULL(b14.betteam, '') AS BetTeam,
					0 AS Hdp1,
					0 AS Hdp2,
					0 AS OddsType,
					b14.odds,
					0 AS MOdds,
					0 AS OddsSpread,
					b14.stake,
					b14.actual_stake,
					b14.status,
					0 AS SettlementStatus,
					b14.transdate,
					b14.winlostdate,
					b14.winlost - b14.actual_stake AS WinLost,
					b14.awinlost,
					b14.mwinlost,
					b14.swinlost,
					b14.playercomm,
					b14.comm - b14.playercomm AS Comm,
					b14.acomm - b14.comm AS AComm,
					b14.scomm - b14.acomm AS SComm,
					b14.apositiontaking,
					b14.mpositiontaking,
					b14.spositiontaking,
					b14.tpositiontaking,
					CASE
						WHEN b2.recommend IN (-3, -4) THEN 0
						ELSE b14.discount
					END AS ADiscount,
					CASE
						WHEN b2.mrecommend = -4 THEN 0
						ELSE b14.adiscount
					END AS MDiscount,
					b14.sdiscount,
					'0' AS ComStatus,
					0 AS LiveIndicator,
					0 AS LiveHomeScore,
					0 AS LiveAwayScore,
					0 AS HtHomeScore,
					0 AS HtAwayScore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					b2.ip,
					0 AS LeagueId,
					0 AS MatchId,
					'' AS MatchCode,
					'' AS Race,
					NULL AS EventDate,
					0 AS HomeId,
					0 AS AwayId,
					'' AS BetStatus,
					0 AS IsNeutral,
					'' AS Placing,
					'' AS ShowTime,
					ISNULL(b14.BetID3rd, '') AS BetCheck,
					ISNULL(b14.transdesc, '') AS TransDesc,
					-1 AS BetdaqId,
					b14.ExtraInfo,
					'' AS JackpotInfo,
					b14.SiteId,
					12 AS WhTicket,
					b14.DeviceType,
					0 AS LeagueGroupId
				FROM dbo.bettransg14 AS b14 WITH (NOLOCK)
					INNER JOIN dbo.bettrans14 AS b2 WITH (NOLOCK) ON b2.transid = b14.refno AND b2.custid = b14.CustId
				WHERE b14.transid = @TransId
			END
		END
	END

	-- Get ticket detail
	IF @Product in ('VR')		-- Virtual Sports Racing
	BEGIN
		IF @WhTicket = 2
		BEGIN
			INSERT INTO @Detail (RefNo, Odds, Stake, Status, APositionTaking, MPositionTaking, SPositionTaking, BetType, BetTeam)
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.mpositiontaking,
				bm.spositiontaking,
				bm.bettype,
				bm.betteam
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @Data AS b ON bm.refno = b.RefNo AND bm.custid = @CustId
				INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			WHERE b.TransId = @TransId
				AND sbt.ProductID IN (5)
				AND sbt.EventType = 3
		END

		IF @WhTicket = 3
		BEGIN
			INSERT INTO @Detail (RefNo, Odds, Stake, Status, APositionTaking, MPositionTaking, SPositionTaking, BetType, BetTeam)
			SELECT
				bm14.refno,
				bm14.odds,
				bm14.stake,
				bm14.status,
				bm14.apositiontaking,
				bm14.mpositiontaking,
				bm14.spositiontaking,
				bm14.bettype,
				bm14.betteam
			FROM dbo.bettransm14 AS bm14 WITH (NOLOCK)
				INNER JOIN @Data AS b ON bm14.refno = b.RefNo AND bm14.custid = @CustId
				INNER JOIN @SportBettype AS sbt ON bm14.bettype = sbt.Bettype
			WHERE b.TransId = @TransId
				AND sbt.ProductID  IN (5)
				AND sbt.EventType = 3
		END
	END

	SELECT
		TransId,
		RefNo,
		CustId,
		Username,
		Currency,
		CurrencyId,
		SportType,
		BetType,
		BetId,
		BetTeam,
		Hdp1,
		Hdp2,
		OddsType,
		Odds,
		MOdds,
		OddsSpread,
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
		ComStatus,
		LiveIndicator,
		LiveHomeScore,
		LiveAwayScore,
		HtHomeScore,
		HtAwayScore,
		FinalHomeScore,
		FinalAwayScore,
		Ip,
		LeagueId,
		MatchId,
		MatchCode,
		Race,
		EventDate,
		HomeId,
		AwayId,
		BetStatus,
		IsNeutral,
		Placing,
		ShowTime,
		BetCheck,
		TransDesc,
		BetdaqId,
		ExtraInfo,
		JackpotInfo,
		SiteId,
		WhTicket,
		DeviceType,
		LeagueGroupId
	FROM @Data
	ORDER BY TransDate DESC

	SELECT DISTINCT 
		RefNo,
		Odds,
		Stake,
		Status,
		APositionTaking,
		MPositionTaking,
		SPositionTaking,
		BetType,
		BetTeam
	FROM @Detail
END
GO
