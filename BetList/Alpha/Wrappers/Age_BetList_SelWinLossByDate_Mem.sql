/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelWinLossByDate_Mem]
	@CustId					INT,
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@MoveBetsDay			SMALLDATETIME,
	@ProductIds				VARCHAR(MAX),
	@ProductDetails			VARCHAR(MAX)	= '',
	@ShowProgressiveBonus	BIT				= 0,
	@IsExportExcel			BIT				= 0,
	@MaxTotalRow			INT				= 1000000	OUTPUT,
	@ErrCode				INT				= 0			OUTPUT,
	@ErrMsg					NVARCHAR(4000)	= ''		OUTPUT
AS

/*
	Created: 20090122@[creator]
	Task: [description of SP]
	DB: DBAGE.bodb02
	Original: BetsSelMWinLoss

	Revisions:
		- 20070205@[Thien]: Always get data from bettrans and bettrans14
		- 20080401@[Thien]: Remove @GetOldData
		- 20080417@[Thien]: Add matchid
		- 20080620@[Thien]: Add betstatus
		- 20080629@[Viet]: remove UNION, uses temporary table instead, Remove Teamname, Leaguename, Sportname, TypeName also
		- 20080805@[Thien]: - Remove DB06.bodb_archive.dbo.bettrans_bk, separate to new DB.
							- Remove temp Table Also
							- Add @MoveBetsDay
		- 20081106@[VinhTring]: Get more result(Sporttype: Horseracing) for betlist
		- 20090226@[HiepVo]: Get more result for Casino Integration
		- 20090321@[HiepVo]: Include Refno, BetID for casino
		- 20090407@[HanhVu]: remove redundant transid field
		- 20090409@[HiepVo]: Change bettrans.status of Casino to NOT IN ('running','waiting')
		- 20090411@[HiepVo]: Insert column BetID to table: @BetListByDateMem
		- 20090416@Minh: remove indexName
		- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@HiepVo: Change formula of commission
		- 20090522@HiepVo: More filter: ShowHR, ShowFI. Add F.O Horse Racing bet type (split Sport Book); Get more data from bettransm for HR
		- 20090708@[Hanh]: order by TransID from bettrans table instead of order by RefNo
		- 20090710@Phuc: unhide IP for TB currency
		- 20090930@Phuc: Show the refunded tickets' status based on bettrans.status
		- 20091003@[MinhNguyen]: get oddstype
		- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100902@Kiwi: Add Number Game & IBCBet Bingo
		- 20101203@Qui: Fix bug show OddsType of NumberGame
		- 20110110@Thien: Record more custid from @BetListByDateMem, in order to optimize INNER JOIN with bettransm/bettransm14
						- index hint for bettransm/bettransm14
		- 20110308@Lukas: change @showHR -> @showRB, add more sporttype 152 & 153
		- 20110408@Amy: Change function to get Odds value and showed odds type
						Show odds value and odds type for Number Game
		- 20110518@Johnson: change bettype,sporttype columns in temporary table to smallint
		- 20110801@Sophia: change the range of number game's bettype from 81 to 120, add new bettype 29 for Combination Mix parlay
		- 20110809@Sophia: Not to use function f_GetChoice to get betteam (bettype <> 14, 16)
		- 20110811@Sophia: Add new columns actual_stake and modds
		- 20111207@Sophia: Change the sportsbook of P2P to 253
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice , f_ShowOddsByBettype
		- 20120120@Sophia: Add showtime for Table - Shoe - Hand of LiveCasino
						- Add Sub table for Live Casino
		- 20120419@Lukas: Show transid of main ticket for subticket of system parlay
		- 20120502@Johnson: Get session id(betcheck) for bets list P2P
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Show hdp1 for Number game
		- 20120807@Sophia: Add new parametter @showVS for Virtual Sports (sporttype = 180 for representing)
						- Remove Financial product
		- 20120927@Sophia: Get comstatus
		- 20130225@Elodie: Add bet list of Virtual HR
		- 20130820@Kathy: Apply Progressive Bonus: bettype 72 for Casino
		- 20140306@Patrick: Add more Keno product
		- 20140310@Patrick: Exclude keno from Sportbook
		- 20140907@Dom: [Redmine #22012] remove duplicate VS transaction id in bet list feature
		- 20141103@Dom: Apply sport bettype matrix
		- 20150302@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216, 217
		- 20150522@Bobby: Add GD product
		- 20150526@Bobby: Implement bet list core
		- 20150706@Bobby: #39097 - Fixing bug for showing Keno's bettype info
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150828@Kos: Support Colossus Bet
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20151217@Kos: Support Cockfighting (#Redmine: 48850)
		- 20160215@Kos: Support AllBet [#Redmine: 50864]
		- 20160331@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160519@Francis: Change to use inline function to enhance performance
		- 20160811@Kos: Support NG2
		- 20161101@Kos: Support Fishing World [#Redmine: 65934]
		- 20170327@Kos: Change input params for Microsite bet list [#Redmine: 66992]
					- Support Betradar Virtual Sports [#Redmine: 77280]
		- 20181014@Viet: rewrite sp [#Redmine: 101405]
		- 20181121@Kos: Support Gold Deluxe - SicBo & BidMe [#Redmine: 101690]
		- 20181128@Kos: Hotfix - Running Casino ticket [#Redmine: 105393]
		- 20181220@Kos: Hotfix - Jackpot Contribution [#Redmine: 106772]
		- 20181227@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190506@Kos: Show match KO time for single ticket [Redmine: #112092]
		- 20190524@Kos: Support BetBuilder [Redmine: #106905]
		- 20190611@Kos: Support Card Club [Redmine: #107645]
					- Don't support Poker Games anymore
					- Remove param @Language
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20191127@Kos: Hotfix - Oddsspread data type [Redmine: #124483]
		- 20191128@Kos: Support Spadegaming [Redmine: #122140]
		- 20191218@Kos: Support Virtual Games [Redmine: #124759]
		- 20200302@Kos: Support SA Gaming [Redmine: #128048]
		- 20200324@Kos: Support Sexy Gaming [Redmine: #130680]
		- 20200331@Kos: Support Saba.club [Redmine: #130769]
		- 20200402@Kos: Support Table Games [Redmine: #129433]
		- 20200422@Kos: Support status Delay Payout [Redmine: #132629]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200507@Kos: Support IBCBet Live Casino [Redmine: #130688]
		- 20200513@Kos: Support BBIN [Redmine: #131362]
		- 20200526@Kos: Support RNG War [Redmine: #132017]
		- 20200609@Kos: Support ION [Redmine: #132329]
		- 20200625@Kos: Integrate archive process for table VSRaceInfo [Redmine: #135963]
		- 20200730@Kos: Support PP Jackpot [Redmine: #138482]
		- 20200808@Kos: Support PG Soft [Redmine: #137769]
		- 20200907@Kos: Support PP Jackpot [Redmine: #137942]
		- 20200919@Kos: Support Joker [Redmine: #137942]
		- 20201001@Kos: Support WM Live Casino [Redmine: #131588]
		- 20201207@Kos: Support GDG [Redmine: #144104]
		- 20201217@Kos: Support Leap Gaming Virtual Sports 3 [Redmine: #131371]
		- 20201222@Kos: Support Big Gaming [Redmine: #142455]
		- 20201224@Kos: Support Happy 5 Linked Games [Redmine: #146540]
		- 20210114@Razor: Support MaxGame [Redmine: #147568]
		- 20210129@Kos: Support God Of Fortune [Redmine: #149740]
		- 20210202@Kos: Support Saba Promotion [Redmine: #149952]
		- 20210301@Razor: Support Sports Lottery [Redmine: #147368]
		- 20210311@Razor: Support PP Live Casino [Redmine: #134042]
		- 20210319@Razor: Support Habanero [Redmine: #145460]
		- 20210402@Razor: Support CG [Redmine: #146020]
		- 20210429@Razor: Support VGaming [Redmine: #154047]
		- 20210513@Razor: Support AdvantPlay [Redmine: #154259]
		- 20210513@Razor: Support AdvantPlay Mini [Redmine: #155134]
		- 20210531@Kos: Prevent high CPU [Redmine: #154749]
					- Add new params @MaxTotalRow INT, @ErrCode INT, @ErrMsg NVARCHAR(4000), @IsExportExcel BIT
		- 20210602@Razor: Support Sexy Gaming Lucky Draw [Redmine: #156237]
		- 20210705@Razor: Show Odds for Happy 5 Linked Games [Redmine: #154704]
		- 20210706@Razor: Display Decimal Odds for Decimal Odds Only Bettypes [#Redmine: 157545]
		- 20210813@Razor: Support Bitcoin [Redmine: #159041]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211130@Razor: Support new Cash out model [Redmine: #164903]
		- 20211223@Razor: Support Third Party Result API [Redmine: #165815]
		- 20220124@Razor: Support SG Jackpot [Redmine: #166683]
		- 20220222@Razor: Support Allbet Promotion [Redmine: #166981]
		- 20220317@Razor: Support FGG [Redmine: #165683]
		- 20220422@Razor: Support Virtual games result [Redmine: #170997]
		
	Param's Explanation:
		@ProductDetails:
			<ROOT>
				<ProductId="32" Sporttype="248" Bettype="0" />
				<ProductId="32" Sporttype="248" Bettype="4298" />
				<ProductId="32" Sporttype="248" Bettype="4297" />
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON;

	-- Get Betradar Virtual Sports in addition to Virtual Sports
	SET @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)

	-- Check SP Version
	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	IF @ShowProgressiveBonus = 1 SET @ProductIds += ',6' -- duplicate values is ok

	DECLARE @f_date	SMALLDATETIME,
		@t_date		SMALLDATETIME,
		@Yesterday	SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0),
		@TotalRow	INT = 0,
		@TotalRow14	INT = 0

	-- CHECK for MoveBetsDay
	IF @MoveBetsDay IS NULL
	BEGIN
		SELECT @MoveBetsDay = MAX(Winlostdate)
		FROM dbo.bettrans14 WITH (NOLOCK)
	END

	CREATE TABLE #MemBetTicket (
		TransId				BIGINT
		, RefNo				BIGINT
		, CustId			INT
		, Username			NVARCHAR(50)
		, SportType			SMALLINT
		, BetType			SMALLINT
		, BetId				BIGINT
		, BetTeam			NVARCHAR(20)
		, Hdp1				SMALLMONEY
		, Hdp2				SMALLMONEY
		, OddsType			TINYINT
		, OddsId			INT
		, Odds				MONEY
		, MOdds				MONEY
		, Stake				MONEY
		, Actual_Stake		MONEY
		, Status			NVARCHAR(10)
		, SettlementStatus	TINYINT
		, TransDate			DATETIME
		, WinLostDate		SMALLDATETIME
		, WinLost			MONEY
		, AWinLost			MONEY
		, MWinLost			MONEY
		, SWinLost			MONEY
		, PlayerComm		MONEY
		, Comm				MONEY
		, AComm				MONEY
		, SComm				MONEY
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, TPositionTaking	SMALLMONEY
		, ADiscount			SMALLMONEY
		, MDiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, LiveIndicator		BIT
		, LiveHomeScore		SMALLINT
		, LiveAwayScore		SMALLINT
		, FinalHomeScore	SMALLINT
		, FinalAwayScore	SMALLINT
		, HtHomeScore		SMALLINT
		, HtAwayScore		SMALLINT
		, Ip				VARCHAR(45)
		, LeagueId			INT
		, MatchId			INT
		, MatchCode			NVARCHAR(50)
		, Race				NVARCHAR(20)
		, EventDate			DATETIME
		, HomeId			INT
		, AwayId			INT
		, BetStatus			NVARCHAR(50)
		, IsNeutral			BIT
		, Placing			NVARCHAR(20)
		, ShowTime			NVARCHAR(50)
		, BetCheck			NVARCHAR(50)
		, ComStatus			NVARCHAR(20)
		, TransDesc			NVARCHAR(1000)
		, OddsSpread		MONEY
		, BetdaqId			BIGINT
		, ExtraInfo			VARCHAR(1000)
		, Currency			NVARCHAR(50)
		, Product			VARCHAR(30)
		, CurrencyId		TINYINT
		, SiteId			VARCHAR(20)
	);

	DECLARE @BettransDetail TABLE (
		RefNo				BIGINT
		, Odds				MONEY
		, Stake				MONEY
		, Status			NVARCHAR(10)
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, BetType			SMALLINT
		, BetTeam			NVARCHAR(10)
		, TransDesc			VARCHAR(300)
	)

	DECLARE @Tickets TABLE (
		TransId			BIGINT
		, RefNo			BIGINT
		, WinLostDate	SMALLDATETIME
		, Product		VARCHAR(30)
	)

	DECLARE @temp_bettransX TABLE (
		RefNo				BIGINT
		, Odds				MONEY
		, Stake				MONEY
		, Actual_Stake		MONEY
		, Status			NVARCHAR(10)
		, WinLost			MONEY
		, AWinLost			MONEY
		, MWinLost			MONEY
		, SWinLost			MONEY
		, PlayerComm		MONEY
		, Comm				MONEY
		, AComm				MONEY
		, SComm				MONEY
		, APositiontaking	SMALLMONEY
		, MPositiontaking	SMALLMONEY
		, SPositiontaking	SMALLMONEY
		, TPositiontaking	SMALLMONEY
		, Discount			SMALLMONEY
		, ADiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, OddsSpread		MONEY
	)

	IF @ToDate > @MoveBetsDay	-- bettrans
	BEGIN
		SET @f_date = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
		SET @t_date = @ToDate

		INSERT INTO @Tickets (
			TransID
			, RefNo
			, WinLostDate
			, Product
		)
		SELECT TransID = b.transid
			, refno = b.refno
			, Winlostdate = b.winlostdate
			, Product = CASE
							WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'	-- Sportsbook Parlay
							WHEN s.EventType = 0 AND s.ProductID = 6 THEN 'OneRNG'	-- RNG Casino
							WHEN s.EventType = 0 AND s.ProductID = 8 THEN 'Keno'
							WHEN s.EventType = 0 AND s.ProductID = 12 THEN 'GD'		-- Gold Deluxe
							WHEN s.EventType = 0 AND s.ProductID = 21 THEN 'AllBet'
							WHEN s.EventType = 0 AND s.ProductID = 22 THEN 'VB'		-- Macau Games
							WHEN s.EventType = 0 AND s.ProductID = 23 THEN 'NG2'
							WHEN s.EventType = 0 AND s.ProductID = 24 THEN 'FW'		-- Fishing World
							WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2' --Betradar Virtual Sports Parlay
							WHEN s.EventType = 0 AND s.ProductID = 28 THEN 'Lottery'
							WHEN s.EventType = 0 AND s.ProductID = 32 THEN 'PP'		-- Pragmatic Play Casino
							WHEN s.ProductID = 34						THEN 'CC'	-- Card Club
							WHEN s.ProductID = 36						THEN 'SG'	-- Spadegaming
							WHEN s.ProductID = 37						THEN 'SPR'	-- Saba Promotion
							WHEN s.ProductID = 38						THEN 'VRG'	-- Virtual Games
							WHEN s.ProductID = 39						THEN 'SAG'	-- SA Gaming
							WHEN s.ProductID = 40						THEN 'TG'	-- Table Games
							WHEN s.ProductID = 42						THEN 'SBC'	-- Saba.club
							WHEN s.ProductID = 45						THEN 'SXG'	-- Sexy Gaming
							WHEN s.ProductID = 46						THEN 'IBCLC'	-- IBCBet Live Casino
							WHEN s.ProductID = 47						THEN 'BBIN'	-- BBIN
							WHEN s.ProductID = 49						THEN 'VS3'	-- Leap Gaming Virtual Sports 3
							WHEN s.ProductID = 50						THEN 'RNGW'	-- RNG War
							WHEN s.ProductID = 51						THEN 'WM'	-- WM
							WHEN s.ProductID = 52						THEN 'ION'	-- ION
							WHEN s.ProductID = 55						THEN 'PGS'	-- PG Soft
							WHEN s.ProductID = 56						THEN 'JK'	-- Joker
							WHEN s.ProductID = 57						THEN 'BG'	-- Big Gaming
							WHEN s.ProductID = 59						THEN 'GDG'	-- GDG
							WHEN s.ProductID = 60						THEN 'MXG'	-- MaxGame
							WHEN s.ProductID = 61						THEN 'HB'	-- Habanero
							WHEN s.ProductID = 62						THEN 'CG'	-- CG
							WHEN s.ProductID = 63						THEN 'SLT'	-- Sports Lottery
							WHEN s.ProductID = 65						THEN 'PPL'	-- PP Live Casino
							WHEN s.ProductID = 66						THEN 'VGA'	-- VGaming
							WHEN s.ProductID = 67						THEN 'AP'	-- AdvantPlay
							WHEN s.ProductID = 68						THEN 'APM'	-- AdvantPlay Mini
							WHEN s.ProductID = 69						THEN 'BTC'	-- Bitcoin
							WHEN s.ProductID = 70						THEN 'FGGL'	-- FGG
							WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'		-- Number Game
							WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'	-- Number Game - Happy 5 Linked Games
							WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'		-- Virtual Sports:: sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'	-- Betradar Virtual Sports
							WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
							WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'		-- Virtual sports:: racing
							ELSE 'Unknown'
						END
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) AS s ON b.bettype = s.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @f_date AND @t_date
			AND 1 = CASE
						WHEN b.statusID > 1 THEN 1
						WHEN s.ProductID IN (6, 21, 22, 24, 32, 34, 36, 39, 42, 45, 46, 50, 51, 52, 55, 56, 57, 59, 60, 61, 62, 65, 66, 67, 68, 70) THEN 1 -- don't care status of casino's summary rows.
						ELSE 0
					END

		IF @@ROWCOUNT > 0
		BEGIN
			-- bettransRnG
			IF EXISTS (SELECT 1 FROM @Tickets WHERE Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM')
				AND WinLostDate >= @Yesterday)
			BEGIN
				INSERT INTO @temp_bettransX
				SELECT RefNo = c.transid
					,Odds = CASE
								WHEN Product IN ('OneRNG', 'PP', 'SG') THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
								ELSE 0 END
					,Stake = SUM(brng.stake)
					,actual_stake = SUM(brng.actual_stake)
					,Status = CASE
									WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
									WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
									ELSE 'Draw'
								END
					,WinLost = SUM(brng.winlost - brng.actual_stake)
					,awinlost = SUM(brng.awinlost)
					,mwinlost = SUM(brng.mwinlost)
					,swinlost = SUM(brng.swinlost)
					,PlayerComm = SUM(brng.playercomm)
					,Comm = SUM(brng.comm - brng.playercomm)
					,AComm = SUM(brng.acomm - brng.comm)
					,SComm = SUM(brng.scomm - brng.acomm)
					,APositiontaking = AVG(brng.APositiontaking)
					,MPositiontaking = AVG(brng.MPositiontaking)
					,SPositiontaking = AVG(brng.SPositiontaking)
					,TPositiontaking = AVG(brng.TPositiontaking)
					,discount = AVG(brng.discount)
					,adiscount = AVG(brng.adiscount)
					,sdiscount = AVG(brng.sdiscount)
					,OddsSpread = CASE WHEN c.Product IN ('OneRNG', 'PP', 'SG') THEN ISNULL(SUM(brng.BetStake), 0) ELSE 0 END
				FROM @Tickets AS c
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.transid
				WHERE c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM')
					AND c.WinLostDate >= @Yesterday
					AND brng.statusID NOT IN (0, 1)
				GROUP BY c.transid, c.Product
			END

			IF EXISTS (SELECT 1 FROM @Tickets WHERE Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND WinLostDate >= @Yesterday) -- bettransLC
			BEGIN
				INSERT INTO @temp_bettransX
				SELECT RefNo = c.transid
					,Odds = 0
					,Stake = SUM(blc.stake)
					,actual_stake = SUM(blc.actual_stake)
					,Status = CASE
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw' END
					,WinLost = SUM(blc.winlost - blc.actual_stake)
					,awinlost = SUM(blc.awinlost)
					,mwinlost = SUM(blc.mwinlost)
					,swinlost = SUM(blc.swinlost)
					,PlayerComm = SUM(blc.playercomm)
					,Comm = SUM(blc.comm - blc.playercomm)
					,AComm = SUM(blc.acomm - blc.comm)
					,SComm = SUM(blc.scomm - blc.acomm)
					,APositiontaking = AVG(blc.APositiontaking)
					,MPositiontaking = AVG(blc.MPositiontaking)
					,SPositiontaking = AVG(blc.SPositiontaking)
					,TPositiontaking = AVG(blc.TPositiontaking)
					,discount = AVG(blc.discount)
					,adiscount = AVG(blc.adiscount)
					,sdiscount = AVG(blc.sdiscount)
					,OddsSpread = 0
				FROM @Tickets AS c
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.transid
				WHERE c.Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL')
					AND c.WinLostDate >= @Yesterday
					AND blc.statusID NOT IN (0, 1)
				GROUP BY c.transid, c.Product
			END -- end: bettransLC

			DELETE b
			FROM @Tickets AS b
			WHERE b.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL')
				AND b.Winlostdate >= @Yesterday
				AND NOT EXISTS (SELECT 1 FROM @temp_bettransX WHERE RefNo = b.TransId)

			SELECT @TotalRow = COUNT(1)
			FROM @Tickets

			IF @TotalRow <= @MaxTotalRow OR @IsExportExcel = 1
			BEGIN
				INSERT INTO #MemBetTicket
				SELECT TransId = CASE
									WHEN c.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END 
					,RefNo = b.refno
					,CustId = b.custid
					,Username = b.username
					,SportType = CASE
									WHEN c.Product IN ('OneRNG', 'CC', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'SXG', 'IBCLC', 'BBIN', 'RNGW', 'ION', 'PGS', 'JK', 'WM', 'GDG', 'VS3', 'BG', 'H5LG', 
										'MXG', 'SPR', 'SLT', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL') THEN b.matchid
									WHEN c.Product = 'Keno' THEN 202
									WHEN c.Product = 'GD' THEN 255 -- Gold Deluxe
									WHEN c.Product = 'AllBet' THEN 211 -- AllBet
									WHEN c.Product = 'VB' THEN 212 -- Macau Games
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
									WHEN c.Product = 'FW' THEN 219 -- Fishing World
									WHEN c.Product = 'Lottery' THEN 220 -- Lottery
									WHEN c.Product = 'PP' THEN 248 -- Pragmatic Casino
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.sporttype
									WHEN c.Product IN ('Outright') THEN l.sporttype
									WHEN c.Product IN ('VR') THEN vr.SportType
									WHEN c.Product IN ('BTC') THEN m3rd.sporttype
									ELSE 0
								END -- parlay(s)
					,BetType = b.bettype
					,BetId = ISNULL(b.betid, 0)
					,BetTeam = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC') THEN b.betteam
									ELSE ''
								END
					,Hdp1 = CASE
								WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp1 -- parlay(s), NG2, Pokergames
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'BTC') THEN b.hdp1
								WHEN c.Product IN ('VR') THEN b.hdp1
								ELSE 0 END
					,Hdp2 = CASE
								WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp2 --parlay(s), NG2
								WHEN c.Product IN ('SB', 'VS', 'VS2') THEN b.hdp2
								WHEN c.Product IN ('VR') THEN b.hdp2
								ELSE 0 END
					,OddsType = CASE
									WHEN c.Product IN ('SB', 'Outright', 'NG', 'VS', 'VS2', 'Keno') THEN b.oddstype
									ELSE 0 END
					,OddsId = b.oddsid
					,Odds = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.Odds IS NOT NULL THEN x.Odds
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'VS3', 'Parlay', 'OneRNG', 'PP', 'SG', 'Keno', 'GD', 'NG2', 'ParlayVS2', 'Lottery', 'VRG', 'TG', 'H5LG', 'SLT', 'BTC') THEN b.Odds
								WHEN c.Product IN ('Outright') THEN b.odds
								WHEN c.Product IN ('VR') THEN b.odds
								ELSE 0 END
					,MOdds = CASE
								WHEN c.Product IN ('Parlay', 'ParlayVS2')  THEN b.modds 
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.modds
								WHEN c.Product IN ('Outright') THEN b.modds
								WHEN c.Product IN ('VR') THEN b.modds
								ELSE 0 END
					,Stake = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.Stake IS NOT NULL THEN x.Stake
								ELSE b.stake END
					,Actual_Stake = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.Actual_Stake IS NOT NULL THEN x.Actual_Stake
									ELSE b.actual_stake END
					,Status = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.status IS NOT NULL THEN x.status
									WHEN c.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
									WHEN c.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
									ELSE b.status
								END
					,SettlementStatus = CASE
											WHEN c.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
											ELSE 0
										END
					,TransDate = b.transdate
					,WinLostDate = b.winlostdate
					,WinLost = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.WinLost IS NOT NULL THEN x.WinLost
									ELSE b.winlost - b.actual_stake END
					,AWinLost = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.AWinLost IS NOT NULL THEN x.AWinLost
									ELSE b.awinLost END
					,MWinLost = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.MWinLost IS NOT NULL THEN x.MWinLost
									ELSE b.mwinLost END
					,SWinLost = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.SWinLost IS NOT NULL THEN x.SWinLost
									ELSE b.SwinLost END
					,PlayerComm = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.PlayerComm IS NOT NULL THEN x.PlayerComm
									ELSE b.playercomm END
					,Comm = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.Comm IS NOT NULL THEN x.Comm
								ELSE b.comm - b.playercomm END
					,AComm = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.AComm IS NOT NULL THEN x.AComm
								ELSE b.acomm - b.comm END
					,SComm = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.SComm IS NOT NULL THEN x.SComm
								ELSE b.scomm - b.acomm END
					,APositionTaking = CASE
											WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.APositiontaking IS NOT NULL THEN x.APositiontaking
											ELSE b.APositiontaking END
					,MPositionTaking = CASE
											WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.MPositiontaking IS NOT NULL THEN x.MPositiontaking
											ELSE b.MPositiontaking END
					,SPositionTaking = CASE
											WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.SPositiontaking IS NOT NULL THEN x.SPositiontaking
											ELSE b.SPositiontaking END
					,TPositionTaking = CASE
											WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.TPositiontaking IS NOT NULL THEN x.TPositiontaking
											ELSE b.TPositiontaking END
					,ADiscount = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.discount IS NOT NULL THEN x.discount
									ELSE b.discount END
					,MDiscount = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.adiscount IS NOT NULL THEN x.adiscount
									ELSE b.adiscount END
					,SDiscount = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL') AND x.sdiscount IS NOT NULL THEN x.sdiscount
									ELSE b.sdiscount END	
					,LiveIndicator = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay') THEN b.liveindicator
										ELSE 0 END
					,LiveHomeScore = CASE 
										WHEN c.Product IN ('Parlay', 'NG2') THEN b.Livehomescore 
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.livehomescore
										WHEN c.Product IN ('Outright') THEN b.livehomescore
										WHEN c.Product IN ('VR') THEN b.livehomescore
										ELSE 0 END
					,LiveAwayScore = CASE
										WHEN c.Product IN ('Parlay') THEN b.Liveawayscore 
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveawayscore
										WHEN c.Product IN ('Outright') THEN b.liveawayscore
										WHEN c.Product IN ('VR') THEN b.liveawayscore
										ELSE 0 END
					,FinalHomeScore = CASE
											WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalhomescore
											ELSE 0 END
					,FinalAwayScore = CASE
											WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalawayscore
											ELSE 0 END
					,HtHomeScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.hthomescore
										ELSE 0 END
					,HtAwayScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.htawayscore
										ELSE 0 END
					,Ip = b.ip
					,LeagueId = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.leagueid
									WHEN c.Product IN ('Outright') THEN o.leagueid
									WHEN c.Product IN ('VR') THEN vr.LeagueID
									ELSE 0 END
					,MatchId = CASE
									WHEN c.Product IN ('GD') THEN 255
									WHEN c.Product IN ('NG2') THEN b.betdaqid
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchid
									WHEN c.Product IN ('Outright') THEN o.orid
									WHEN c.Product IN ('VR', 'BTC') THEN b.matchid
									ELSE 0 END
					,MatchCode = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchcode
									WHEN c.Product IN ('Outright') THEN o.matchcode
									WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE '' END
					,Race = CASE
									WHEN c.Product IN ('Outright') THEN o.groupmatch
									WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
									ELSE '' END
					,EventDate = CASE
									WHEN c.Product = 'SB' THEN m.GlobalShowTime
									WHEN c.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
									WHEN c.Product IN ('Outright') THEN o.eventdate
									WHEN c.Product IN ('VR') THEN vo.EventDate
									WHEN c.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.winlostdate END
					,HomeId = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.homeid
									WHEN c.Product IN ('Outright') THEN o.teamid
									WHEN c.Product IN ('VR') THEN vo.RacerID
									ELSE 0 END
					,AwayId = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.awayid
									ELSE 0 END
					,BetStatus = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.betstatus
									ELSE '' END
					,IsNeutral = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0 END
					,Placing = CASE
									WHEN c.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE '' END
					,ShowTime = CASE
									WHEN c.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN c.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
									WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE '' END
					,BetCheck = CASE 
									WHEN c.Product IN ('SB', 'Parlay', 'ParlayVS2', 'GD', 'VRG', 'H5LG', 'SLT') THEN ISNULL(b.betcheck, '')
									WHEN c.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									ELSE '' END
					,ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END
					,TransDesc = CASE
									WHEN c.Product IN ('OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'FW', 'Lottery', 'PP', 'VRG', 'TG', 'PGS', 'JK', 'SLT', 'HB', 'CG', 'AP', 'APM') THEN b.transdesc
									WHEN c.Product IN ('SB', 'VS2', 'VS3', 'H5LG') THEN ISNULL(b.transdesc, '')
									ELSE '' END
					,OddsSpread = CASE
									WHEN c.Product IN ('OneRNG', 'PP', 'SG') AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
									WHEN c.Product IN ('SB', 'OneRNG', 'PP', 'SG') THEN ISNULL(b.oddsspread, 0)
									ELSE 0 END
					,BetdaqId = CASE
									WHEN c.Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END
					,ExtraInfo = CASE
									WHEN c.Product IN ('SB', 'VS3', 'Parlay', 'SPR') THEN ISNULL(b.ExtraInfo, '')
									ELSE '' END
					,Currency = b.currencyname
					,Product = c.Product
					,CurrencyId = CASE
									WHEN c.Product IN ('H5LG', 'SLT') THEN b.currency
									ELSE 0
								END
					,SiteId = CASE
								WHEN c.Product IN ('VRG', 'H5LG', 'SLT') THEN CONVERT(VARCHAR(20), b.betdaqid)
								ELSE ''
							END
				FROM @Tickets AS c
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = c.transid
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
					LEFT JOIN @temp_bettransX AS x
						ON c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL', 'FGGL')
						AND c.Winlostdate >= @Yesterday
						AND x.RefNo = c.transid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON c.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON c.Product IN ('Outright') AND o.leagueID = l.leagueID
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON c.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON c.Product IN ('VR') AND vr.EventID = vo.EventID
					LEFT JOIN dbo.match3rd AS m3rd WITH (NOLOCK) ON b.matchid = m3rd.match3rdid
					
				-- virtual sports:: racing
				INSERT INTO @BettransDetail
				SELECT RefNo = bm.refno
					,Odds = bm.odds
					,Stake = bm.stake
					,Status = bm.status
					,APositionTaking = bm.apositiontaking
					,MPositionTaking = bm.mpositiontaking
					,SPositionTaking = bm.spositiontaking
					,BetType = bm.bettype
					,BetTeam = bm.betteam
					,TransDesc = ''
				FROM @Tickets AS c
					INNER JOIN dbo.bettransm AS bm WITH(NOLOCK) ON c.Product IN ('VR') AND c.refno = bm.refno AND bm.custid = @custid
				WHERE c.Product IN ('VR') -- virtual sports:: racing
	
				UNION ALL --Gold Deluxe
				SELECT RefNo = bg.refno
					,Odds = bg.odds
					,Stake = bg.stake
					,Status = bg.status
					,APositionTaking = bg.apositiontaking
					,MPositionTaking = bg.mpositiontaking
					,SPositionTaking = bg.spositiontaking
					,BetType = bg.bettype
					,BetTeam = bg.betteam
					,TransDesc = bg.transdesc
				FROM @Tickets AS c
					INNER JOIN dbo.bettransg AS bg WITH(NOLOCK) ON c.Product IN ('GD') AND c.transid = bg.refno AND bg.custid = @custid
				WHERE c.Product IN ('GD') --Gold Deluxe
			END
		END
	END
	
	IF @FromDate <= @MoveBetsDay	--bettrans14
	BEGIN
		SET @f_date = @FromDate
		SET @t_date = CASE WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END
		
		DELETE FROM @Tickets

		INSERT INTO @Tickets (
			TransId,
			RefNo,
			Product
		)
		SELECT
			TransID = b.transid,
			RefNo = b.refno,
			Product = CASE
							WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'	-- Sportsbook Parlay
							WHEN s.EventType = 0 AND s.ProductID = 6 THEN 'OneRNG'	-- RNG Casino
							WHEN s.EventType = 0 AND s.ProductID = 8 THEN 'Keno'
							WHEN s.EventType = 0 AND s.ProductID = 12 THEN 'GD'		-- Gold Deluxe
							WHEN s.EventType = 0 AND s.ProductID = 21 THEN 'AllBet'
							WHEN s.EventType = 0 AND s.ProductID = 22 THEN 'VB'		-- Macau Games
							WHEN s.EventType = 0 AND s.ProductID = 23 THEN 'NG2'
							WHEN s.EventType = 0 AND s.ProductID = 24 THEN 'FW'		-- Fishing World
							WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2' --Betradar Virtual Sports Parlay
							WHEN s.EventType = 0 AND s.ProductID = 28 THEN 'Lottery'
							WHEN s.EventType = 0 AND s.ProductID = 32 THEN 'PP'		-- Pragmatic Play Casino
							WHEN s.ProductID = 34					THEN 'CC'		-- Card Club
							WHEN s.ProductID = 36					THEN 'SG'		-- Spadegaming
							WHEN s.ProductID = 37					THEN 'SPR'		-- Saba Promotion
							WHEN s.ProductID = 38					THEN 'VRG'		-- Virtual Games
							WHEN s.ProductID = 39					THEN 'SAG'		-- SA Gaming
							WHEN s.ProductID = 40					THEN 'TG'		-- Table Games
							WHEN s.ProductID = 42					THEN 'SBC'		-- Saba.club
							WHEN s.ProductID = 45					THEN 'SXG'		-- Sexy Gaming
							WHEN s.ProductID = 46					THEN 'IBCLC'	-- IBCBet Live Casino
							WHEN s.ProductID = 47					THEN 'BBIN'		-- BBIN
							WHEN s.ProductID = 49					THEN 'VS3'		-- Leap Gaming Virtual Sports 3
							WHEN s.ProductID = 50					THEN 'RNGW'		-- RNG War
							WHEN s.ProductID = 51					THEN 'WM'		-- WM
							WHEN s.ProductID = 52					THEN 'ION'		-- ION
							WHEN s.ProductID = 55					THEN 'PGS'		-- PG Soft
							WHEN s.ProductID = 56					THEN 'JK'		-- Joker
							WHEN s.ProductID = 57					THEN 'BG'		-- Big Gaming
							WHEN s.ProductID = 59					THEN 'GDG'		-- GDG
							WHEN s.ProductID = 60					THEN 'MXG'		-- MaxGame
							WHEN s.ProductID = 61					THEN 'HB'		-- Habanero
							WHEN s.ProductID = 62					THEN 'CG'		-- CG
							WHEN s.ProductID = 63					THEN 'SLT'		-- Sports Lottery
							WHEN s.ProductID = 65					THEN 'PPL'		-- PP Live Casino
							WHEN s.ProductID = 66					THEN 'VGA'		-- VGaming
							WHEN s.ProductID = 67					THEN 'AP'		-- AdvantPlay
							WHEN s.ProductID = 68					THEN 'APM'		-- AdvantPlay Mini
							WHEN s.ProductID = 69					THEN 'BTC'		-- Bitcoin
							WHEN s.ProductID = 70					THEN 'FGGL'		-- FGG
							WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'		-- Number Game
							WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'	-- Number Game - Happy 5 Linked Games
							WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'		-- Virtual Sports:: sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'	-- Betradar Virtual Sports
							WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
							WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'		-- virtual sports:: racing
							ELSE 'unknown' END
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) AS s ON b.bettype = s.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @f_date AND @t_date

		SELECT @TotalRow14 = COUNT(1)
		FROM @Tickets
		
		IF @TotalRow14 > 0
			AND (@TotalRow + @TotalRow14 <= @MaxTotalRow OR @IsExportExcel = 1)
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT TransId = CASE WHEN c.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid END 
				,RefNo = b.refno
				,CustId = b.custid
				,Username = b.username
				,SportType = CASE
								WHEN c.Product IN ('OneRNG', 'CC', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'SXG', 'IBCLC', 'BBIN', 'RNGW', 'ION', 'PGS', 'JK', 'WM', 'GDG', 'VS3', 'BG', 'H5LG', 
									'MXG', 'SPR', 'SLT', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL') THEN b.matchid
								WHEN c.Product = 'Keno' THEN 202
								WHEN c.Product = 'GD' THEN 255 -- Gold Deluxe 
								WHEN c.Product = 'AllBet' THEN 211 -- AllBet
								WHEN c.Product = 'VB' THEN 212 -- Macau Games
								WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
								WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
								WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
								WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
								WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
								WHEN c.Product = 'FW' THEN 219 -- Fishing World
								WHEN c.Product = 'Lottery' THEN 220 -- Lottery
								WHEN c.Product = 'PP' THEN 248 -- Pragmatic Casino
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.sporttype
								WHEN c.Product IN ('Outright') THEN l.sporttype
								WHEN c.Product IN ('VR') THEN vr.SportType
								WHEN c.Product IN ('BTC') THEN m3rd.sporttype
								ELSE 0 END -- parlay(s)
				,BetType = b.bettype
				,BetId = ISNULL(b.betid, 0)
				,BetTeam = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC') THEN b.betteam
								ELSE ''	END 
				,Hdp1 = CASE
							WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp1 -- parlay(s), NG2
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'BTC') THEN b.hdp1
							WHEN c.Product IN ('VR') THEN b.hdp1
							ELSE 0 END
				,Hdp2 = CASE
							WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp2 --parlay(s), NG2
							WHEN c.Product IN ('SB', 'VS', 'VS2') THEN b.hdp2
							WHEN c.Product IN ('VR') THEN b.hdp2
							ELSE 0 END
				,OddsType = CASE 
								WHEN c.Product IN ('SB', 'Outright', 'NG', 'VS', 'VS2', 'Keno') THEN b.oddstype
								ELSE 0 END
				,OddsId = b.oddsid
				,Odds = CASE 
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'VS3', 'Outright', 'VR', 'Parlay', 'OneRNG', 'PP', 'SG', 'Keno', 'GD', 'NG2', 'ParlayVS2', 'Lottery', 'VRG', 'TG', 'H5LG', 'SLT', 'BTC') THEN b.Odds
							ELSE 0 END
				,MOdds = CASE 
							WHEN c.Product IN ('Parlay', 'ParlayVS2')  THEN b.modds 
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.modds
							WHEN c.Product IN ('Outright') THEN b.modds
							WHEN c.Product IN ('VR') THEN b.modds
							ELSE 0 END
				,Stake = b.stake
				,Actual_Stake = b.actual_stake
				,Status = CASE
							WHEN c.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
							WHEN c.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
							ELSE b.status
						END
				,SettlementStatus = 0
				,TransDate = b.transdate
				,WinLostDate = b.winlostdate
				,WinLost = b.winlost - b.actual_stake
				,AWinLost = b.awinLost
				,MWinLost = b.mwinLost
				,SWinLost = b.swinLost
				,PlayerComm = b.playercomm
				,Comm = b.comm - b.playercomm
				,AComm = b.acomm - b.comm
				,SComm = b.scomm - b.acomm
				,APositionTaking = b.APositiontaking
				,MPositionTaking = b.MPositiontaking
				,SPositionTaking = b.SPositiontaking
				,TPositionTaking = b.TPositiontaking
				,ADiscount = b.discount
				,MDiscount = b.adiscount
				,SDiscount = b.sdiscount
				,LiveIndicator = CASE 
									WHEN c.Product IN ('Parlay') THEN b.Liveindicator 
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveindicator
									ELSE 0 END
				,LiveHomeScore = CASE 
									WHEN c.Product IN ('Parlay', 'NG2') THEN b.livehomescore 
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.livehomescore
									WHEN c.Product IN ('Outright') THEN b.livehomescore
									WHEN c.Product IN ('VR') THEN b.livehomescore
									ELSE 0 END
				,LiveAwayScore = CASE 
									WHEN c.Product IN ('Parlay') THEN b.Liveawayscore 
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveawayscore
									WHEN c.Product IN ('Outright') THEN b.liveawayscore
									WHEN c.Product IN ('VR') THEN b.liveawayscore
									ELSE 0 END
				,FinalHomeScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalhomescore
										ELSE 0 END
				,FinalAwayScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalawayscore
										ELSE 0 END
				,HtHomeScore = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.hthomescore
									ELSE 0 END
				,HtAwayScore = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.htawayscore
									ELSE 0 END
				,Ip = b.ip
				,LeagueId = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.leagueid
								WHEN c.Product IN ('Outright') THEN o.leagueid
								WHEN c.Product IN ('VR') THEN vr.LeagueID
								ELSE 0 END
				,MatchId = CASE
								WHEN c.Product IN ('GD') THEN 255
								WHEN c.Product IN ('NG2') THEN b.betdaqid
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchid
								WHEN c.Product IN ('Outright') THEN o.orid
								WHEN c.Product IN ('VR', 'BTC') THEN b.matchid
								ELSE 0 END
				,MatchCode = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchcode
								WHEN c.Product IN ('Outright') THEN o.matchcode
								WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
								ELSE '' END
				,Race = CASE
								WHEN c.Product IN ('Outright') THEN o.groupmatch
								WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE '' END
				,EventDate = CASE
								WHEN c.Product = 'SB' THEN m.GlobalShowTime
								WHEN c.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
								WHEN c.Product IN ('Outright') THEN o.eventdate
								WHEN c.Product IN ('VR') THEN vo.EventDate
								WHEN c.Product IN ('BTC') THEN m3rd.EndTime
								ELSE b.winlostdate END
				,HomeId = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.homeid
								WHEN c.Product IN ('Outright') THEN o.teamid
								WHEN c.Product IN ('VR') THEN vo.RacerID
								ELSE 0 END
				,AwayId = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.awayid
								ELSE 0 END
				,BetStatus = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.betstatus
								ELSE '' END
				,IsNeutral = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
								ELSE 0 END
				,Placing = CASE
								WHEN c.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
								ELSE '' END
				,ShowTime = CASE
								WHEN c.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
								WHEN c.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
								WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
								ELSE '' END
				,BetCheck = CASE 
								WHEN c.Product IN ('SB', 'Parlay', 'ParlayVS2', 'GD', 'VRG', 'H5LG', 'SLT') THEN ISNULL(b.betcheck, '')
								WHEN c.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
								ELSE '' END
				,ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END
				,TransDesc = CASE
								WHEN c.Product IN ('OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'FW', 'Lottery', 'PP', 'VRG', 'TG', 'PGS', 'JK', 'SLT', 'HB', 'CG', 'AP', 'APM') THEN b.transdesc
								WHEN c.Product IN ('SB', 'VS2', 'VS3', 'H5LG') THEN ISNULL(b.transdesc, '')
								ELSE '' END
				,OddsSpread = CASE
								WHEN c.Product IN ('SB', 'OneRNG', 'PP', 'SG') THEN ISNULL(b.oddsspread, 0)
								ELSE 0 END
				,BetdaqId = CASE
								WHEN c.Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
								ELSE -1
							END
				,ExtraInfo = CASE
								WHEN c.Product IN ('SB', 'VS3', 'Parlay', 'SPR') THEN ISNULL(b.ExtraInfo, '')
								ELSE '' END
				,Currency = b.currencyname
				,Product = c.Product
				,CurrencyId = CASE
								WHEN c.Product IN ('H5LG', 'SLT') THEN b.currency
								ELSE 0
							END
				,SiteId = CASE
							WHEN c.Product IN ('VRG', 'H5LG', 'SLT') THEN CONVERT(VARCHAR(20), b.betdaqid)
							ELSE ''
						END
			FROM @Tickets AS c
				INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON b.transid = c.transid
				LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
				LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON c.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON c.Product IN ('Outright') AND o.leagueID = l.leagueID
				LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON c.Product IN ('VR') AND b.oddsid = vo.Orid
				LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON c.Product IN ('VR') AND vr.EventID = vo.EventID
				LEFT JOIN dbo.match3rd14 AS m3rd WITH (NOLOCK) ON b.matchid = m3rd.match3rdid

			INSERT INTO @BettransDetail
			-- virtual sports:: racing
			SELECT RefNo = bm.refno
				,Odds = bm.odds
				,Stake = bm.stake
				,Status = bm.status
				,APositionTaking = bm.apositiontaking
				,MPositionTaking = bm.mpositiontaking
				,SPositionTaking = bm.spositiontaking
				,BetType = bm.bettype
				,BetTeam = bm.betteam
				,TransDesc = ''
			FROM @Tickets AS c
				INNER JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON c.Product IN ('VR') AND c.refno = bm.refno AND bm.custid = @custid
			WHERE c.Product IN ('VR') -- virtual sports:: racing
	
			UNION ALL --Gold Deluxe
			SELECT RefNo = bg.refno
				,Odds = bg.odds
				,Stake = bg.stake
				,Status = bg.status
				,APositionTaking = bg.apositiontaking
				,MPositionTaking = bg.mpositiontaking
				,SPositionTaking = bg.spositiontaking
				,BetType = bg.bettype
				,BetTeam = bg.betteam
				,TransDesc = bg.transdesc
			FROM @Tickets AS c
				INNER JOIN dbo.bettransg14 AS bg WITH (NOLOCK) ON c.Product IN ('GD') AND c.transid = bg.refno AND bg.custid = @custid
			WHERE c.Product IN ('GD') --Gold Deluxe
		END -- end: @@rowcount > 0
	END -- end: bettrans14

	-- Filter due to product detail
	-- AllBet, Pragmatic, Spadegaming, Sexy Gaming
	IF EXISTS (SELECT 1 FROM #MemBetTicket WHERE Product IN ('AllBet', 'PP', 'SG', 'SXG'))
	BEGIN
		DECLARE @ProductDetail TABLE (
			ProductId	TINYINT,
			SportType	SMALLINT,
			BetType		SMALLINT
		)

		IF ISNULL(@ProductDetails, '') <> ''
		BEGIN
			DECLARE @DocHandler INT

			BEGIN TRY
				EXEC sp_xml_preparedocument @DocHandler OUTPUT, @ProductDetails

				INSERT INTO @ProductDetail (ProductId, SportType, BetType)
				SELECT ProductId, SportType, BetType
				FROM OPENXML(@DocHandler, '/ROOT/ProductDetail', 1) WITH (ProductId TINYINT, Sporttype SMALLINT, Bettype SMALLINT)

				EXEC sp_xml_removedocument @DocHandler
			END TRY
			BEGIN CATCH
				RETURN
			END CATCH
		END

		DECLARE @FullProductDetail TABLE (
			ProductId	TINYINT,
			SportType	SMALLINT,
			BetType		SMALLINT
		)

		INSERT INTO @FullProductDetail
		SELECT
			ProductId,
			SportType,
			BetType
		FROM dbo.f_GetProductDetail()

		DELETE b
		FROM #MemBetTicket AS b
		WHERE b.Product = 'Allbet'
			AND NOT EXISTS (SELECT 1 FROM @ProductDetail
							WHERE ProductId = 21 AND BetType = b.BetType)
			AND EXISTS (SELECT 1 FROM @FullProductDetail
							WHERE ProductId = 21 AND BetType = b.BetType)

		DELETE b
		FROM #MemBetTicket AS b
		WHERE b.Product = 'Allbet'
			AND NOT EXISTS (SELECT 1 FROM @ProductDetail
							WHERE ProductId = 21 AND BetType = 0)
			AND NOT EXISTS (SELECT 1 FROM @FullProductDetail
							WHERE ProductId = 21 AND BetType = b.BetType)

		DELETE b
		FROM #MemBetTicket AS b
		WHERE b.Product = 'PP'
			AND NOT EXISTS (SELECT 1 FROM @ProductDetail
							WHERE ProductId = 32 AND BetType = b.BetType)
			AND EXISTS (SELECT 1 FROM @FullProductDetail
							WHERE ProductId = 32 AND BetType = b.BetType)

		DELETE b
		FROM #MemBetTicket AS b
		WHERE b.Product = 'PP'
			AND NOT EXISTS (SELECT 1 FROM @ProductDetail
							WHERE ProductId = 32 AND BetType = 0)
			AND NOT EXISTS (SELECT 1 FROM @FullProductDetail
							WHERE ProductId = 32 AND BetType = b.BetType)

		DELETE b
		FROM #MemBetTicket AS b
		WHERE b.Product = 'SXG'
			AND NOT EXISTS (SELECT 1 FROM @ProductDetail
							WHERE ProductId = 45 AND BetType = b.BetType)
			AND EXISTS (SELECT 1 FROM @FullProductDetail
							WHERE ProductId = 45 AND BetType = b.BetType)

		DELETE b
		FROM #MemBetTicket AS b
		WHERE b.Product = 'SXG'
			AND NOT EXISTS (SELECT 1 FROM @ProductDetail
							WHERE ProductId = 45 AND BetType = 0)
			AND NOT EXISTS (SELECT 1 FROM @FullProductDetail
							WHERE ProductId = 45 AND BetType = b.BetType)

		DELETE b
		FROM #MemBetTicket AS b
		WHERE b.Product = 'SG'
			AND NOT EXISTS (SELECT 1 FROM @ProductDetail
							WHERE ProductId = 36 AND BetType = b.BetType)
			AND EXISTS (SELECT 1 FROM @FullProductDetail
							WHERE ProductId = 36 AND BetType = b.BetType)

		DELETE b
		FROM #MemBetTicket AS b
		WHERE b.Product = 'SG'
			AND NOT EXISTS (SELECT 1 FROM @ProductDetail
							WHERE ProductId = 36 AND BetType = 0)
			AND NOT EXISTS (SELECT 1 FROM @FullProductDetail
							WHERE ProductId = 36 AND BetType = b.BetType)
	END

	DECLARE @OriginalMaxTotalRow INT

	SET @OriginalMaxTotalRow = @MaxTotalRow

	IF @TotalRow + @TotalRow14 > @MaxTotalRow
	BEGIN
		IF @IsExportExcel = 0
			DELETE FROM #MemBetTicket

		SELECT @ErrCode = 100,
			@ErrMsg = N'Exceed max total row.',
			@MaxTotalRow = @TotalRow + @TotalRow14
	END

	IF @IsExportExcel = 0 OR @OriginalMaxTotalRow >= @TotalRow + @TotalRow14
	BEGIN
		SELECT *
		FROM #MemBetTicket
		ORDER BY TransId DESC
	END
	ELSE
	BEGIN
		SELECT TOP(@OriginalMaxTotalRow) *
		FROM #MemBetTicket
		ORDER BY TransId DESC
	END

	SELECT *
	FROM @BettransDetail
	ORDER BY RefNo DESC

	DROP TABLE #MemBetTicket
END
GO
