/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinloss_Mem]
	@AgentList			VARCHAR(MAX),
	@CustId				INT,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@DrawFilter			SMALLINT	= 1,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@ShowSB				BIT			= 0,
	@ShowNG				BIT			= 0,
	@ShowBA				BIT			= 0,
	@ShowVS				BIT			= 0,
	@ShowCS				BIT			= 0,	-- RNG Casino
	@ShowKN				BIT			= 0,	-- Keno
	@ShowAGC			BIT			= 0,	-- AG Casino
	@ShowAB				BIT			= 0,	-- AllBet
	@ShowVB				BIT			= 0,	-- Voidbridge
	@ShowVS2			BIT			= 0,	-- Betradar Virtual Sports
	@ShowLT				BIT			= 0,	-- Lottery
	@ShowPP				BIT			= 0,	-- Pragmatic Casino
	@ShowCC				BIT			= 0,	-- Card Club
	@ShowSG				BIT			= 0,	-- Spadegaming
	@ShowVRG			BIT			= 0,	-- Virtual Games
	@ShowSAG			BIT			= 0,	-- SA Gaming
	@ShowTG				BIT			= 0,	-- Table Games
	@ShowSBC			BIT			= 0,	-- Saba.club
	@ShowI4D			BIT			= 0,	-- Indo 4D
	@ShowSXG			BIT			= 0,	-- Sexy Gaming
	@ShowPGS			BIT			= 0,	-- PG Soft
	@ShowJK				BIT			= 0,	-- Joker
	@ShowSLT			BIT			= 0,	-- Sports Lottery
	@ShowHB				BIT			= 0,	-- Habanero
	@ShowWM				BIT			= 0,	-- WM Live Casino
	@ShowBGG			BIT			= 0,	-- Big Gaming
	@ShowVGA			BIT			= 0,	-- Vgaming
	@ShowCG				BIT			= 0,	-- CG
	@ShowAP				BIT			= 0,	-- AdvantPlay
	@ShowAPM			BIT			= 0,	-- AdvantPlay Mini
	@ShowVS3			BIT			= 0,	-- Virtual Sports 3 (Old)
	@ShowBTC			BIT			= 0,	-- Bitcoin
	@ShowFGGL			BIT			= 0,	-- FGG
	@ShowMXG			BIT			= 0,	-- MaxGame
	@ShowJIG			BIT			= 0,	-- Jili
	@ShowYB				BIT			= 0,	-- YeeBet
	@ShowMGRNG			BIT			= 0,	-- MG-RNG
	@ShowLG				BIT			= 0,	-- Virtual Sports 3
	@ShowBT				BIT			= 0,	-- Bet Trade
	@ShowCO				BIT			= 0,	-- Cash Out
	@BaseCurrency		VARCHAR(12),
	@PageSize			INT			= 1000,
	@PageIndex			INT			= 1,
	@TotalRows			INT			= 0 OUTPUT,
	@SumWinLost			MONEY		= 0 OUTPUT,
	@SumLicenseeWL		MONEY		= 0 OUTPUT,
	@SumComm			MONEY		= 0 OUTPUT,
	@SumPlayerComm		MONEY		= 0 OUTPUT
AS

/*
	Created: Henry@20120109
	Task: Betlist for Licensee Winloss Report
	DB: DBACC.bodb02

	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of system parlay
		- 20120529@Henry: enhance performance
		- 20120703@Henry: add value to column hdp1, hdp2 for Number Game
		- 20120717@Jim: add paging filter
		- 20120723@Jim: add playercomm value
		- 20120816@Henry: add ShowLiveCasino
		- 20120911@Jim : add virtual sport
		- 20130123@Daniel: Change link server alias
		- 20130204@Jim: support RNG Casino and Bingo product
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20130716@Jim: update matchid for RNG Casino and Bingo
		- 20130809@Jim: offer Virtual Horse Racing
		- 20140307@Hannah: offer Keno
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20140908@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141128@winnie: change currency keenocean
		- 20150124@winnie: Add base currency GBP
		- 20150406@Winnie: Add 60 bettypes Betradar & Apply matrix of sporttype & bettype 
		- 20150515@Winnie: fix bug
		- 20150604@Edward: Support Microgaming
		- 20150608@Edward: Support Bet Trade
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150828@Edward: Fixed Odds value of ticket 901, 902 is displayed incorrectly
		- 20150914@Kos: Support Microgaming RNG Casino
		- 20150922@Kos: Support AG Casino
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151224@Jim: Fix bug [Redmine: #49885]
		- 20151225@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160216@Kos: Support yesterday running ticket [Redmine: #52277]
		- 20160405@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160412@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160714@Kos: Remove Bingo code and change to use inline function for SportBettypeMatrix
		- 20160726@Kos: Support AllBet [#Redmine: 61066]
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160913@Kos: Support Colossus Bets [#Redmine: 63785]
		- 20161004@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20161111@Kos: Support Fishing World [#Redmine: 66737]
		- 20161205@Kos: Fix Colossus Bets bet list empty before BalanceUpDay [Redmine: #68289]
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]
		- 20170302@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170331@Kos: Support CashOut [#Redmine: 71963]
		- 20170602@Kos: Get liveindicator from original ticket for 912 tickets [#Redmine: 77669]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170721@Kos: Support Keno Lottery [#Redmine: 79997]
		- 20180205@Kos: Add more condition for SB in Parlay [#Redmine: 90492]
		- 20180226@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180305@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
		- 20180329@Kos: Support Fast Market 2 [#Redmine: 90879]
		- 20180420@Kos: Include bet type 911 for Cash Out [#Redmine: 93919]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 94829]
		- 20180525@Kos: Support Pragmatic Casino [#Redmine: 92318]
		- 20180806@Kos: Don't support Racing anymore [#Redmine: 99378]
		- 20181102@Kos: Remove DBLIC linked server [#Redmine: 103660]
		- 20190401@Kos: Don't support Microgaming Live Casino and Microgaming RNG Casino anymore [#Redmine: 107704]
					- Remove params @ShowMGCLC and @ShowMGCRNG
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190520@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Remove params @SumWinLostUSD, @SumWinLostEUR, @SumWinLostGBP, ...
		- 20190715@Kos: Hotfix - Show KickOffTime Incorrectly [#Redmine: 116777]
		- 20190716@Kos: Support Card Club [Redmine: #115449]
		- 20191119@Kos: Don't support bettype Promotion Prize (4300) and Tournament Prize (4299) [Redmine: #123804]
		- 20191206@Kos: Support Spadegaming [Redmine: #124103]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200221@Kos: Support Virtual Games [Redmine: #124911]
		- 20200402@Kos: Support Table Games [Redmine: #131447]
		- 20200416@Kos: Support Indo 4D [Redmine: #130859]
		- 20200425@Kos: Support status Delay Payout [Redmine: #132629]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200511@Kos: Support Sexy Gaming [Redmine: #130859]
		- 20200518@Kos: Support Saba.club [Redmine: #132702]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20200714@Kos: Support PP Jackpot [Redmine: #137290]
		- 20200728@Kos: Support SA Gaming [Redmine: #128493]
		- 20201023@Kos: Exclude Arcadia Gaming Bonus ticket [Redmine: #143648]
		- 20201109@Kos: Support PG Soft [Redmine: #139182]
		- 20201123@Kos: Support Joker [Redmine: #141408]
		- 20201207@Kos: Exclude Saba.club Free Bet ticket [Redmine: #142369]
		- 20201231@Kos: Support Happy 5 Linked Games [Redmine: #147446]
		- 20210112@Kos: Support GDG [Redmine: #147267]
		- 20210118@Kos: Exclude Saba.club Jackpot Contribution and Jackpot Prize tickets [Redmine: #148100]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210311@Kos: Support Sports Lottery [Redmine: #150872]
		- 20210415@Kos: Support Habanero [Redmine: #150843]
		- 20210506@Kos: Support WM Live Casino [Redmine: #140944]
		- 20210517@Kos: Support Big Gaming [Redmine: #146773]
		- 20210524@Kos: Support Vgaming [Redmine: #151583]
		- 20210705@Kos: Support Happy 5 Linked Games - Soccer 5 [Redmine: #154898]
		- 20210714@Kos: Support CG [Redmine: #152619]
		- 20210715@Kos: Support Beach Volleyball [Redmine: #157296]
		- 20210913@Kos: Hotfix - Missing CG [Redmine: #161485]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211029@Kos: Decompress IP in bk range [Redmine: 162342]
		- 20211102@Kos: Support AdvantPlay and AdvantPlay Mini [Redmine: #158186]
		- 20220113@Kos: Support new 3rd result API [Redmine: #166047]
		- 20220215@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220227@Kos: Support Virtual Sports 3 [Redmine: #145337]
		- 20220428@Kos: Support Bitcoin [RedmineID: #160160]
		- 20220526@Kos: Support FGG [Redmine: #167897]
		- 20220527@Kos: Support MaxGame [RedmineID: #172919]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20230119@Kos: Support Jili [Redmine: 182914]
		- 20230328@Kos: Remove inactive products CB, FW, GDG [Redmine: 181424]
		- 20230602@Kos: Support YeeBet [Redmine: 187947]
		- 20230629@Kos: Support MG-RNG [Redmine: 189988]
		- 20230803@Kos: Support Virtual Sports 3 [Redmine: 190908]

	Param's Explanation:
		+ @DrawFilter: 'No Draw' filter is supportted
			- 1: Normal
			- 2: No Draw
			- 3: No Draw for Turnover only
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	DECLARE @fdate SMALLDATETIME,
		@tdate SMALLDATETIME

	SELECT @fdate = @FromDate,
		@tdate = @ToDate

	DECLARE @BetListByDateMem AS TABLE (
		SportType			INT,
		TransId				BIGINT,
		BetId				BIGINT,
		BetType				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		MOdds				MONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		BetTeam				NVARCHAR(20),
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		RefNo				BIGINT,
		TransDate			DATETIME,
		WinLostDate			DATETIME,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(20),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		VirtualRate			FLOAT,
		IsShowOTExRate		BIT,
		Currency			INT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		OddsSpread			MONEY,
		SiteId				VARCHAR(20)
	)

	DECLARE @TempBetList AS TABLE (
		TransId			BIGINT,
		BetId			BIGINT,
		BetType			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		BetTeam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNo			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		Currency		INT,
		MatchId			INT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		OddsSpread		MONEY
	)

	DECLARE @ExchangeRate TABLE (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 3, 5, 6, 8, 11, 21, 22, 25, 27, 28, 32, 34, 36, 38, 39, 40, 42, 43, 45, 49, 51, 55, 56, 57, 60, 61, 62, 63, 66, 67, 68, 69, 70, 73, 75, 76, 77)
		AND Bettype NOT IN (904, 914)
		AND BetType NOT IN (SELECT BetType FROM dbo.Lrf_f_SelExcludedBetType())

	IF @ShowBT = 0
	BEGIN
		DELETE @SportBettype
		WHERE ProductID = 1 AND Bettype IN (901, 902, 903)
	END

	DELETE FROM @SportBettype
	WHERE (ProductID	= CASE WHEN @ShowSB = 0 AND @ShowBA = 0 THEN 1 END AND Bettype NOT IN (901, 902, 903))
		OR ProductID	= CASE WHEN @ShowNG = 0		THEN 3 END
		OR ProductID	= CASE WHEN @ShowVS = 0		THEN 5 END
		OR ProductID	= CASE WHEN @ShowCS = 0		THEN 6 END
		OR ProductID	= CASE WHEN @ShowKN = 0		THEN 8 END
		OR ProductID	= CASE WHEN @ShowAGC = 0	THEN 11 END
		OR ProductID	= CASE WHEN @ShowAB = 0		THEN 21 END
		OR ProductID	= CASE WHEN @ShowVB = 0		THEN 22 END
		OR ProductID	= CASE WHEN @ShowCO = 0		THEN 25 END
		OR ProductID	= CASE WHEN @ShowVS2 = 0	THEN 27 END
		OR ProductID	= CASE WHEN @ShowLT = 0		THEN 28 END
		OR ProductID	= CASE WHEN @ShowPP = 0		THEN 32 END
		OR ProductID	= CASE WHEN @ShowCC = 0		THEN 34 END
		OR ProductID	= CASE WHEN @ShowSG = 0		THEN 36 END
		OR ProductID	= CASE WHEN @ShowVRG = 0	THEN 38 END
		OR ProductID	= CASE WHEN @ShowSAG = 0	THEN 39 END
		OR ProductID	= CASE WHEN @ShowTG = 0		THEN 40 END
		OR ProductID	= CASE WHEN @ShowSBC = 0	THEN 42 END
		OR ProductID	= CASE WHEN @ShowI4D = 0	THEN 43 END
		OR ProductID	= CASE WHEN @ShowSXG = 0	THEN 45 END
		OR ProductID	= CASE WHEN @ShowVS3 = 0	THEN 49 END
		OR ProductID	= CASE WHEN @ShowWM = 0		THEN 51 END
		OR ProductID	= CASE WHEN @ShowPGS = 0	THEN 55 END
		OR ProductID	= CASE WHEN @ShowJK = 0		THEN 56 END
		OR ProductID	= CASE WHEN @ShowBGG = 0	THEN 57 END
		OR ProductID	= CASE WHEN @ShowMXG = 0	THEN 60 END
		OR ProductID	= CASE WHEN @ShowHB = 0		THEN 61 END
		OR ProductID	= CASE WHEN @ShowCG = 0		THEN 62 END
		OR ProductID	= CASE WHEN @ShowSLT = 0	THEN 63 END
		OR ProductID	= CASE WHEN @ShowVGA = 0	THEN 66 END
		OR ProductID	= CASE WHEN @ShowAP = 0		THEN 67 END
		OR ProductID	= CASE WHEN @ShowAPM = 0	THEN 68 END
		OR ProductID	= CASE WHEN @ShowBTC = 0	THEN 69 END
		OR ProductID	= CASE WHEN @ShowFGGL = 0	THEN 70 END
		OR ProductID	= CASE WHEN @ShowMGRNG = 0	THEN 73 END
		OR ProductID	= CASE WHEN @ShowJIG = 0	THEN 75 END
		OR ProductID	= CASE WHEN @ShowYB = 0		THEN 76 END
		OR ProductID	= CASE WHEN @ShowLG = 0		THEN 77 END

	IF @tdate > @MoveBetsDay
	BEGIN
		IF @fdate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @fdate

		-- Get BA Tickets
		INSERT INTO @TempBetList
		SELECT
			b.transid,
			ISNULL(b.betid, 0),
			b.Bettype,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake,
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost - b.actual_stake) AS WinLost,
			0,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.ip,
			b.currency,
			b.matchid,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate
			AND b.custid = @CustId
			AND b.statusID IN (111, 112, 113)
			AND b.bettype NOT IN (901, 902, 903)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @BetListByDateMem
			SELECT
				m.sporttype,
				b.TransId,
				b.BetID,
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				b.refno,
				b.TransDate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.Ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				b.transdesc,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake,
				b.OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				b.OddsSpread,
				'' AS SiteId
			FROM
				@TempBetList AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid 
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				b.OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
				m.LeagueID,
				m.OrId,
				m.MatchCode,
				m.GroupMatch,--Race
				b.WinLostDate AS EventDate,
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				@TempBetList AS b
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.BetId, 0) = 0 THEN b.TransId
							ELSE b.BetId
						END
				END AS transid,
				b.BetId,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.Modds,
				0 AS OddsType, 
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.Ip,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				b.WinLostDate AS EventDate,
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM @TempBetList AS b
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE b.matchid IN (9, 29)
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.MatchCode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				ISNULL(b.WalletType, 0) AS WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @CustId
				AND b.bettype NOT IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) -- Exclude BA tickets

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				b.OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.ip,
				m.leagueid,
				m.OrId,
				m.MatchCode,
				m.GroupMatch,--Race
				b.WinLostDate AS EventDate,
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @CustId
				AND sbt.ProductID = 1
				AND sbt.EventType = 2
				AND b.statusID IN (111, 112, 113) 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END

		-- Mix Parlay, System Parlay (Sportsbook), Mix Parlay (Betradar Virtual Sports)
		IF @ShowSB = 1 OR @ShowVS2 = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				0 AS SportType,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.betid, 0) = 0 THEN b.transid
							ELSE b.betid
						END
				END AS transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race
				b.WinLostDate AS EventDate,
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @CustId
				AND (sbt.ProductID = 27
					OR (sbt.ProductID = 1 AND @ShowSB = 1))		-- check in case of @ShowBA = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29, 2799)
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END

		-- BetTrade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.transid,
				ISNULL(ob.bettype,0) AS BetID,
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.OddsType,
				ob.Odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake) AS WinLost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				CASE
					WHEN b.bettype = 903 THEN b.awinlost
					ELSE b.comm
				END AS comm,
				b.playercomm,
				b.liveindicator,
				ob.livehomescore,
				ob.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS ob WITH(NOLOCK) ON b.refno = ob.transid
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @CustId
				AND b.bettype IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0
				AND b.statusID IN (111, 112, 113)
		END

		-- Number Game, Virtual Sports, Betradar Virtual Sports, Virtual Sports 3 (EventType = 1)
		IF @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1 OR @ShowLG = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				b.winlostdate AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CASE 
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE ''
				END AS ShowTime,
				'' AS betcheck,
				CASE
					WHEN sbt.ProductID IN (27, 77) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @CustId
				AND sbt.ProductID IN (3, 5, 27, 77)
				AND sbt.EventType = 1
				AND b.statusID IN (111, 112, 113)
		END

		-- Bitcoin
		IF @ShowBTC = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				m.League3rdId AS LeagueId,
				b.matchid,
				'' AS MatchCode,
				'' AS Race,
				m.EndTime AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @CustId
				AND sbt.ProductID IN (69)
				AND b.statusID IN (111, 112, 113)
		END

		-- Virtual Sports (EventType = 3)
		IF @ShowVS = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				r.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				r.LeagueID,
				o.EventID MatchID,
				CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
				b.oddsid AS Race,
				b.winlostdate AS EventDate,
				o.RacerID HomeID,
				0 AS AwayID,
				r.Betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS showtime,
				'' AS betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @CustId
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, Keno, Lottery, Virtual Games, Table Games, Indo 4D, Happy 5 Linked Games, Sports Lottery, Virtual Sports 3
		IF @ShowCS = 1 OR @ShowKN = 1 OR @ShowLT = 1 OR @ShowVRG = 1 OR @ShowTG = 1 OR @ShowI4D = 1 OR @ShowNG = 1 OR @ShowSLT = 1 OR @ShowVS3 = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 THEN 251
					WHEN sbt.ProductID = 8 THEN 202
					WHEN sbt.ProductID = 28 THEN 220
					WHEN sbt.ProductID IN (3, 38, 40, 43, 49, 63) THEN b.matchid
					ELSE 0
				END AS Sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				ISNULL(b.oddstype, 0),
				b.Odds,
				b.stake,
				b.actual_stake,
				ISNULL(b.betteam, ''),
				CASE
					WHEN sbt.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
					WHEN sbt.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
					ELSE b.status
				END AS status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				0 AS LeagueID,
				CASE
					WHEN sbt.ProductID = 6 THEN b.bettype
					ELSE 0
				END AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				b.winlostdate AS EventDate,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS showtime,
				CASE
					WHEN sbt.ProductId = 8 THEN ISNULL(b.comstatus, '')
					WHEN sbt.ProductID IN (3, 38, 63) THEN ISNULL(b.betcheck, '')
					ELSE ''
				END AS betcheck,
				CASE
					WHEN sbt.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				CONVERT(VARCHAR(20), b.BetdaqId) AS SiteId
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @CustId
				AND (sbt.ProductID IN (8, 28, 38, 40, 43, 49, 63)
					OR (sbt.ProductID = 6 AND sbt.SubProduct = '')
					OR (sbt.ProductID = 3 AND sbt.EventType = 0))
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino Single Wallet, Voidbridge, Pragmatic Casino, Card Club, Spadegaming, Saba.club, PG Soft, Joker, Habanero, Vgaming, CG, AdvantPlay, AdvantPlay Mini
		-- MaxGame, Jili, MG-RNG
		IF @ShowCS = 1 OR @ShowVB = 1 OR @ShowPP = 1 OR @ShowCC = 1 OR @ShowSG = 1 OR @ShowSBC = 1 OR @ShowPGS = 1 OR @ShowJK = 1 
			OR @ShowHB = 1 OR @ShowVGA = 1 OR @ShowCG = 1 OR @ShowAP = 1 OR @ShowAPM = 1 OR @ShowMXG = 1 OR @ShowJIG = 1 OR @ShowMGRNG = 1
		BEGIN
			-- Up to yesterday settled ticket
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID IN (6, 34, 36, 42, 55, 56, 60, 61, 62, 66, 67, 68, 73, 75) THEN b.matchid
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 32 THEN 248
					ELSe 0
				END AS Sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS oddstype,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS Liveindicator,
				0 AS Livehomescore,
				0 AS Liveawayscore,
				b.ip,
				0 AS LeagueID,
				0 AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				b.winlostdate AS EventDate,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				b.transdesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.winlostdate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- not yesterday and today
				AND b.custid = @CustId
				AND (sbt.ProductID IN (22, 32, 34, 36, 42, 55, 56, 60, 61, 62, 66, 67, 68, 73, 75)
					OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
				AND b.statusID IN (111, 112, 113)

			IF @tdate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)				-- yesterday
				AND @TempFromDate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
			BEGIN
				-- Today settled ticket
				INSERT INTO @BetListByDateMem
				SELECT
					CASE
						WHEN sbt.ProductID IN (6, 34, 36, 42, 55, 56, 60, 61, 62, 66, 67, 68, 73, 75) THEN b.matchid
						WHEN sbt.ProductID = 22 THEN 212
						WHEN sbt.ProductID = 32 THEN 248
						ELSE 0
					END AS Sporttype,
					b.transid,
					ISNULL(b.betid, 0),
					b.Bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS oddstype,
					0 AS Odds,
					SUM(brng.stake) AS Stake,
					SUM(brng.actual_stake) AS Actual_Stake,
					'' AS betteam,
					CASE 
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					b.refno,
					b.transdate,
					b.winlostdate,
					SUM(brng.winlost - brng.actual_stake) AS Winlost,
					SUM(- (brng.winlost - brng.actual_stake)) AS LicenseeWL,
					SUM(brng.comm) AS comm,
					SUM(brng.playercomm) AS playercomm,
					0 AS Liveindicator,
					0 AS Livehomescore,
					0 AS Liveawayscore,
					b.ip,
					0 AS LeagueID,
					0 AS MatchID,
					'' AS MatchCode,
					'' AS Race,
					b.winlostdate AS EventDate,
					0 AS HomeID,
					0 AS AwayID,
					0 AS Betstatus,
					CONVERT(BIT, 0) AS IsNeutral,
					0,
					0,
					b.currency,
					'' AS showtime,
					'' AS betcheck,
					b.transdesc,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS OriginalStake,
					0 AS OriginalBetType,
					0 AS WalletType,
					0 AS RefCode,
					0 AS OddsSpread,
					'' AS SiteId
				FROM
					dbo.bettransRnG AS brng WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @tdate
					AND b.winlostdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0) 
						AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- yesterday and today
					AND b.custid = @CustId 
					AND (sbt.ProductID IN (22, 32, 34, 36, 42, 55, 56, 60, 61, 62, 66, 67, 68, 73, 75)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
					AND brng.statusID <> 0
				GROUP BY
					b.transid,
					ISNULL(b.betid, 0),
					b.Bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.ip,
					b.currency,
					b.matchid,
					b.transdesc,
					sbt.ProductID
			END
		END

		-- AG Casino, AllBet, SA Gaming, Sexy Gaming, WM Live Casino, Big Gaming, FGG, YeeBet
		IF @ShowAGC = 1 OR @ShowAB = 1 OR @ShowSAG = 1 OR @ShowSXG = 1 OR @ShowWM = 1 OR @ShowBGG = 1 OR @ShowFGGL = 1 OR @ShowYB = 1
		BEGIN
			-- Up to yesterday settled ticket
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 21 THEN 211
					WHEN sbt.ProductID IN (39, 45, 51, 57, 70, 76) THEN b.matchid
					ELSE 0
				END AS Sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS oddstype,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS Liveindicator,
				0 AS Livehomescore,
				0 AS Liveawayscore,
				b.ip,
				0 AS LeagueID,
				0 AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				b.winlostdate AS EventDate,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.winlostdate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- not yesterday and today
				AND b.custid = @CustId
				AND sbt.ProductID IN (11, 21, 39, 45, 51, 57, 70, 76)
				AND b.statusID IN (111, 112, 113)

			IF @tdate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)				-- yesterday
				AND @TempFromDate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
			BEGIN
				-- Today settled ticket
				INSERT INTO @BetListByDateMem
				SELECT
					CASE
						WHEN sbt.ProductID = 11 THEN 250
						WHEN sbt.ProductID = 21 THEN 211
						WHEN sbt.ProductID IN (39, 45, 51, 57, 70, 76) THEN b.matchid
						ELSE 0
					END AS Sporttype,
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS oddstype,
					0 AS Odds,
					SUM(blc.stake) AS Stake,
					SUM(blc.actual_stake) AS Actual_Stake,
					'' AS betteam,
					CASE 
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					b.refno,
					b.transdate,
					b.winlostdate,
					SUM(blc.winlost - blc.actual_stake) AS Winlost,
					SUM(- (blc.winlost - blc.actual_stake)) AS LicenseeWL,
					SUM(blc.comm) AS comm,
					SUM(blc.playercomm) AS playercomm,
					0 AS Liveindicator,
					0 AS Livehomescore,
					0 AS Liveawayscore,
					b.ip,
					0 AS LeagueID,
					0 AS MatchID,
					'' AS MatchCode,
					'' AS Race,
					b.winlostdate AS EventDate,
					0 AS HomeID,
					0 AS AwayID,
					0 AS Betstatus,
					CONVERT(BIT, 0) AS IsNeutral,
					0,
					0,
					b.currency,
					'' AS showtime,
					'' AS betcheck,
					'' AS transdesc,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS OriginalStake,
					0 AS OriginalBetType,
					0 AS WalletType,
					0 AS RefCode,
					0 AS OddsSpread,
					'' AS SiteId
				FROM
					dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @tdate
					AND b.winlostdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0) 
						AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- yesterday and today
					AND b.custid = @CustId
					AND sbt.ProductID IN (11, 21, 39, 45, 51, 57, 70, 76)
					AND blc.statusID <> 0
				GROUP BY
					b.transid,
					ISNULL(b.betid, 0),
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.ip,
					b.currency,
					sbt.productID,
					b.matchid
			END
		END
	END

	IF @fdate <= @MoveBetsDay AND @tdate >= @BalanceUpDay
	BEGIN
		IF @tdate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @tdate

		IF @BalanceUpDay < @fdate
			SELECT @BalanceUpDay = @fdate

		-- BA Tickets
		DELETE FROM @TempBetList
		
		INSERT INTO @TempBetList
		SELECT
			b.transid,
			ISNULL(b.BetID, 0),
			b.Bettype,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake,
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost - b.actual_stake),
			0,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.ip,
			b.currency,
			b.matchid,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
			AND b.custid = @CustId
			AND b.statusID IN (111, 112, 113)
			AND b.bettype NOT IN (901, 902, 903)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.Ip,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				b.transdesc,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake,
				b.OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				b.OddsSpread,
				'' AS SiteId
			FROM
				@TempBetList AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransId,
				b.BetId,
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				b.OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.Ip,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				b.WinLostDate AS EventDate,
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake,
				b.OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				@TempBetList AS b
				INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.BetId, 0) = 0 THEN b.transid
							ELSE b.BetId
						END
				END AS transid,
				b.BetID,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.Modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.Ip,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race
				b.WinLostDate AS EventDate,
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake,
				b.OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				@TempBetList AS b
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.matchid IN (9, 29)
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2, 
				b.modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				- (b.winlost - b.actual_stake),
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				ISNULL(b.WalletType, 0) AS WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @CustId 
				AND b.bettype NOT IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0 
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				b.OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				- (b.winlost - b.actual_stake),
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.ip,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch AS Race,
				b.winlostdate AS EventDate,
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND sbt.ProductID = 1
				AND sbt.EventType = 2
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END

		-- Mix Parlay, System Parlay (Sportsbook), Mix Parlay (Betradar Virtual Sports)
		IF @ShowSB = 1 OR @ShowVS2 = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				0 AS SportType,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.betid, 0) = 0 THEN b.transid
							ELSE b.betid
						END
				END AS transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race
				b.winlostdate AS EventDate,
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND (sbt.ProductID = 27
					OR (sbt.ProductID = 1 AND @ShowSB = 1))		-- check in case of @ShowBA = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29, 2799)
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END
	
		-- Bet trade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.transid,
				ISNULL(ob.bettype, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.Oddstype,
				ob.Odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				- (b.winlost - b.actual_stake),
				CASE
					WHEN b.bettype = 903 THEN b.awinlost
					ELSE b.comm
				END AS comm,
				b.playercomm,
				b.liveindicator,
				ob.livehomescore,
				ob.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.bettrans14 AS ob WITH(NOLOCK) ON b.refno = ob.transid
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @CustId
				AND b.bettype IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0
				AND b.statusID IN (111, 112, 113)
		END

		-- Number Game, Virtual Sports, Betradar Virtual Sports, Virtual Sports 3 (EventType = 1)
		IF @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1 OR @ShowLG = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				b.winlostdate AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CASE
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE '' 
				END AS ShowTime,
				'' AS betcheck,
				CASE
					WHEN sbt.ProductID IN (27, 77) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND sbt.ProductID IN (3, 5, 27, 77)
				AND sbt.EventType = 1
		END

		-- Bitcoin
		IF @ShowBTC = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				m.League3rdId AS LeagueId,
				b.matchid,
				'' AS MatchCode,
				'' AS Race,
				m.EndTime AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.Match3rd14 AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate
				AND b.custid = @CustId
				AND sbt.ProductID IN (69)
				AND b.statusID IN (111, 112, 113)
		END

		-- Virtual Sports
		IF @ShowVS = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				r.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				- (b.winlost - b.actual_stake),
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				r.LeagueID,
				o.EventID MatchID,
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,
				b.winlostdate AS EventDate,
				o.RacerID HomeID,
				0 AS AwayID,
				r.Betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20), r.EventTime) AS showtime,
				'' AS betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate
				AND b.custid = @CustId
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, Keno, AG Casino, AllBet, Voidbridge, Lottery, Pragmatic Casino, Card Club, Spadegaming
		-- Virtual Games, SA Gaming, Table Games, Indo 4D, Sexy Gaming, Saba.club, PG Soft, Joker, Happy 5 Linked Games, Sports Lottery, Habanero
		-- WM Live Casino, Big Gaming, Vgaming, CG, AdvantPlay, AdvantPlay Mini, Virtual Sports 3, FGG, MaxGame, Jili, YeeBet, MG-RNG
		IF @ShowCS = 1 OR @ShowKN = 1 OR @ShowAGC = 1 OR @ShowAB = 1 OR @ShowVB = 1 OR @ShowLT = 1 OR @ShowPP = 1
			OR @ShowCC = 1 OR @ShowSG = 1 OR @ShowVRG = 1 OR @ShowSAG = 1 OR @ShowTG = 1 OR @ShowSBC = 1 OR @ShowI4D = 1 OR @ShowSXG = 1 OR @ShowPGS = 1
			OR @ShowJK = 1 OR @ShowNG = 1 OR @ShowSLT = 1 OR @ShowHB = 1 OR @ShowWM = 1 OR @ShowBGG = 1 OR @ShowVGA = 1 OR @ShowCG = 1
			OR @ShowAP = 1 OR @ShowAPM = 1 OR @ShowVS3 = 1 OR @ShowFGGL = 1 OR @ShowMXG = 1 OR @ShowJIG = 1 OR @ShowYB = 1 OR @ShowMGRNG = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
					WHEN sbt.ProductID = 8 THEN 202
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 21 THEN 211
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 28 THEN 220
					WHEN sbt.ProductID = 32 THEN 248
					WHEN sbt.ProductID IN (3, 34, 36, 38, 39, 40, 42, 43, 45, 49, 51, 55, 56, 57, 60, 61, 62, 63, 66, 67, 68, 70, 73, 75, 76) THEN b.matchid
					ELSE 0
				END AS Sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.Bettype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.modds
					ELSE 0
				END AS modds,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddstype
					ELSE 0
				END AS Oddstype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Odds
					WHEN sbt.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN b.odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN ISNULL(b.betteam, '')
					ELSE ''
				END AS Betteam,
				CASE
					WHEN sbt.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
					WHEN sbt.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
					ELSE b.status
				END AS status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				- (b.winlost - b.actual_stake),
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0 AS LeagueID,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.bettype
					ELSE 0
				END AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				b.winlostdate AS EventDate,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS showtime,
				CASE
					WHEN sbt.ProductId = 8 THEN ISNULL(b.comstatus, '')
					WHEN sbt.ProductId In (3, 38, 63) THEN ISNULL(b.betcheck, '')
					ELSE ''
				END AS betcheck,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
					WHEN sbt.ProductID IN (3, 8, 22, 28, 32, 34, 36, 38, 40, 43, 49, 55, 56, 61, 62, 63, 67, 68) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS transdesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				CONVERT(VARCHAR(20), b.BetdaqId) AS SiteId
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate
				AND b.custid = @CustId
				AND (sbt.ProductID IN (6, 8, 11, 21, 22, 28, 32, 34, 36, 38, 39, 40, 42, 43, 45, 49, 51, 55, 56, 57, 60, 61, 62, 63, 66, 67, 68, 70, 73, 75, 76)
					OR (sbt.ProductID = 3 AND sbt.EventType = 0))
				AND b.statusID IN (111, 112, 113)
		END
	END

	IF @fdate < @BalanceUpDay
	BEGIN
		IF @tdate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @tdate

		DELETE FROM @TempBetList

		-- BA Tickets
		INSERT INTO @TempBetList
		SELECT
			b.transid,
			ISNULL(b.betid, 0),
			b.Bettype,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake,
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost - b.actual_stake),
			0,
			b.comm,
			b.playercomm,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			dp.IP,
			b.currency,
			b.matchid,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM
			bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk AS BA WITH (NOLOCK) ON b.transid = BA.transid
			CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate
			AND b.custid = @CustId
			AND b.ruben = 1
			AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
			AND b.bettype NOT IN (901, 902, 903)
	
		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.Ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				b.transdesc,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake,
				b.OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				b.OddsSpread,
				'' AS SiteId
			FROM
				@TempBetList AS b
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				b.OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.Ip,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				b.WinLostDate AS EventDate,
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				@TempBetList AS b
				INNER JOIN bodb_Archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + System parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.BetId, 0) = 0 THEN b.transid
							ELSE b.BetId
						END
				END AS transid,
				b.BetID,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.Modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.Ip,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race
				b.WinLostDate AS EventDate,
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				@TempBetList AS b
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				- (b.winlost - b.actual_stake),
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				dp.IP,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				ISNULL(b.WalletType, 0) WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				'' AS SiteId
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId
				AND b.ruben = 1
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
				AND b.bettype NOT IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				b.OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				- (b.winlost - b.actual_stake),
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				dp.IP,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				b.winlostdate AS EventDate,
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId
				AND b.ruben = 1
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
				AND sbt.ProductID = 1
				AND sbt.EventType = 2
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END

		-- Mix Parlay, System Parlay (Sportsbook), Mix Parlay (Betradar Virtual Sports)
		IF @ShowSB = 1 OR @ShowVS2 = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.betid, 0) = 0 THEN b.transid
							ELSE b.betid
						END
				END AS transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				dp.IP,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race
				b.winlostdate AS EventDate,
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId
				AND b.ruben = 1
				AND b.status NOT IN ('VOID', 'REJECT','REFUND')
				AND (sbt.ProductID = 27
					OR (sbt.ProductID = 1 AND @ShowSB = 1))		-- check in case of @ShowBA = 1
				AND sbt.EventType = 0
				AND b.matchid IN (0, 9, 29, 2799) --should NOT remove 0 IN archive
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END

		-- Bet trade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(ob.bettype, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.Oddstype,
				ob.Odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				- (b.winlost - b.actual_stake),
				CASE
					WHEN b.bettype = 903 THEN b.awinlost
					ELSE b.comm
				END AS comm,
				b.playercomm,
				b.liveindicator,
				ob.livehomescore,
				ob.liveawayscore,
				dp.IP,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				'' AS SiteId
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.refno = ob.transid
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId
				AND b.ruben = 1
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
				AND b.bettype IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
		END

		-- Cash Out
		IF @ShowCO = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.bettype, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				- (b.winlost - b.actual_stake),
				CASE
					WHEN b.bettype = 913 THEN b.awinlost
					ELSE b.comm
				END AS comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				dp.IP,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				'' AS SiteId
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId
				AND sbt.ProductID = 25
				AND b.statusID IN (111, 112, 113)

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @BetListByDateMem WHERE BetType = 911)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM @BetListByDateMem AS b
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @BetListByDateMem WHERE BetType = 912)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.Comm, 0)
				FROM @BetListByDateMem AS b
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN @BetListByDateMem AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
				WHERE b.BetType = 912
			END
		END

		-- Number Game, Virtual Sports, Betradar Virtual Sports, Virtual Sports 3 (EventType = 1)
		IF @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1 OR @ShowLG = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				dp.IP,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				b.winlostdate AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CASE 
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE '' 
				END AS ShowTime,
				'' AS betcheck,
				CASE
					WHEN sbt.ProductID IN (27, 77) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid 
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId 
				AND sbt.ProductID IN (3, 5, 27, 77)
				AND sbt.EventType = 1 
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
		END

		-- Bitcoin
		IF @ShowBTC = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				m.League3rdId AS LeagueId,
				b.matchid,
				'' AS MatchCode,
				'' AS Race,
				m.EndTime AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.Match3rd_bk AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId
				AND sbt.ProductID IN (69)
				AND b.statusID IN (111, 112, 113)
		END

		-- Virtual Sports (EventType = 3)
		IF @ShowVS = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				r.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				- (b.winlost - b.actual_stake),
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				dp.IP,
				r.LeagueID,
				o.EventID MatchID,
				CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
				b.oddsid AS Race,
				b.winlostdate AS EventDate,
				o.RacerID HomeID,
				0 AS AwayID,
				r.Betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS showtime,
				'' AS betcheck,
				'' AS transdesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				'' AS SiteId
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN bodb_Archive.dbo.VSRaceInfo_bk AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @CustId 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3 
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, Keno, AG Casino, AllBet, Voidbridge, Lottery, Pragmatic Casino, Card Club, Spadegaming
		-- Virtual Games, SA Gaming, Table Games, Indo 4D, Sexy Gaming, Saba.club, PG Soft, Joker, Happy 5 Linked Games, Sports Lottery, Habanero
		-- WM Live Casino, Big Gaming, Vgaming, CG, AdvantPlay, AdvantPlay Mini, Virtual Sports 3, FGG, MaxGame, Jili, YeeBet, MG-RNG
		IF @ShowCS = 1 OR @ShowKN = 1 OR @ShowAGC = 1 OR @ShowAB = 1 OR @ShowVB = 1 OR @ShowLT = 1 OR @ShowPP = 1
			OR @ShowCC = 1 OR @ShowSG = 1 OR @ShowVRG = 1 OR @ShowSAG = 1 OR @ShowTG = 1 OR @ShowSBC = 1 OR @ShowI4D = 1 OR @ShowSXG = 1 OR @ShowPGS = 1
			OR @ShowJK = 1 OR @ShowNG = 1 OR @ShowSLT = 1 OR @ShowHB = 1 OR @ShowWM = 1 OR @ShowBGG = 1 OR @ShowVGA = 1 OR @ShowCG = 1
			OR @ShowAP = 1 OR @ShowAPM = 1 OR @ShowVS3 = 1 OR @ShowFGGL = 1 OR @ShowMXG = 1 OR @ShowJIG = 1 OR @ShowYB = 1 OR @ShowMGRNG = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
					WHEN sbt.ProductID = 8 THEN 202
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 21 THEN 211
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 28 THEN 220
					WHEN sbt.ProductID = 32 THEN 248
					WHEN sbt.ProductID IN (3, 34, 36, 38, 39, 40, 42, 43, 45, 49, 51, 55, 56, 57, 60, 61, 62, 63, 66, 67, 68, 70, 73, 75, 76) THEN b.matchid
					ELSE 0
				END AS Sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.modds
					ELSE 0
				END AS modds,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddstype
					ELSE 0
				END AS Oddstype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Odds
					WHEN sbt.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN b.odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN ISNULL(b.betteam, '')
					ELSE ''
				END AS Betteam,
				CASE
					WHEN sbt.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
					WHEN sbt.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
					ELSE b.status
				END AS status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				- (b.winlost - b.actual_stake),
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				dp.IP,
				0 AS LeagueID,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.bettype
					ELSE 0
				END AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				b.winlostdate AS EventDate,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS showtime,
				CASE
					WHEN sbt.ProductId = 8 THEN ISNULL(b.comstatus, '')
					WHEN sbt.ProductId IN (3, 38, 63) THEN ISNULL(b.betcheck, '')
					ELSE ''
				END AS betcheck,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
					WHEN sbt.ProductID IN (3, 8, 22, 28, 32, 34, 36, 38, 40, 43, 49, 55, 56, 61, 62, 63, 67, 68) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS transdesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread,
				CONVERT(VARCHAR(20), b.BetdaqId) AS SiteId
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
				CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId
				AND (sbt.ProductID IN (6, 8, 11, 21, 22, 28, 32, 34, 36, 38, 39, 40, 42, 43, 45, 49, 51, 55, 56, 57, 60, 61, 62, 63, 66, 67, 68, 70, 73, 75, 76)
					OR (sbt.ProductID = 3 AND sbt.EventType = 0))
				AND b.ruben = 1
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
		END
	END

	IF @ShowBT = 1
	BEGIN
		UPDATE betList
		SET betList.comm = CASE WHEN betList.Bettype = 902 THEN commBetList.comm ELSE betList.comm END
		FROM @BetListByDateMem AS betList
			INNER JOIN @BetListByDateMem AS commBetList ON betList.RefNO = commBetList.RefNO
		WHERE betList.Sporttype = 1 
			AND betList.Bettype IN (901, 902)
			AND commBetList.Bettype = 903

		DELETE @BetListByDateMem WHERE Sporttype = 1 AND Bettype = 903
	END

	IF @ShowCO = 1
	BEGIN
		DELETE @BetListByDateMem WHERE Bettype = 913
	END

	DELETE @BetListByDateMem
	WHERE Currency NOT IN (SELECT DISTINCT Currency FROM @TempAg)

	-- Exclude draw for no draw option (2)
	DELETE FROM @BetListByDateMem
	WHERE @drawfilter = 2 AND status = 'DRAW' AND ABS(modds) <> 0.25

	-- Exclude Saba.club Free Bet
	DELETE FROM @BetListByDateMem
	WHERE SportType = 150

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM @BetListByDateMem WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode			BIGINT,
			TransId			BIGINT,
			Stake			MONEY,
			Actual_Stake	MONEY,
			WinLost			MONEY,
			LicenseeWL		MONEY,
			Comm			MONEY,
			PlayerComm		MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake,
			SUM(Actual_Stake) AS Actual_Stake,
			SUM(WinLost) AS WinLost,
			SUM(LicenseeWL) AS LicenseeWL,
			SUM(Comm) AS Comm,
			SUM(PlayerComm) AS PlayerComm
		FROM @BetListByDateMem
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
				b.LicenseeWL = r.LicenseeWL,
				b.Comm = r.Comm,
				b.PlayerComm = r.PlayerComm,
				b.WalletType = 0
			FROM @BetListByDateMem AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE @BetListByDateMem
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE @BetListByDateMem
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @BetListByDateMem
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	DECLARE @Currency	INT

	SELECT @Currency = currency
	FROM dbo.Customer WITH (NOLOCK)
	WHERE custid = @CustId

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM @BetListByDateMem

	-- Get exchange rate
	INSERT INTO @ExchangeRate
	SELECT
		e.FromDate,
		e.ToDate,
		e.Rate
	FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
	WHERE e.ExchangeId = @Currency
		AND EXISTS (SELECT 1 FROM @BetListByDateMem WHERE WinLostDate BETWEEN e.FromDate AND e.ToDate)

	-- Return data
	SELECT
		@TotalRows		= COUNT(b.TransId),
		@SumWinlost		= SUM(b.WinLost		* ISNULL(e.Rate, 1)),
		@SumLicenseeWL	= SUM(b.LicenseeWL	* ISNULL(e.Rate, 1)),
		@SumComm		= SUM(b.Comm		* ISNULL(e.Rate, 1)),
		@SumPlayerComm	= SUM(b.PlayerComm	* ISNULL(e.Rate, 1))
	FROM @BetListByDateMem AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, 
		@RowStart = @PageSize * @PageIndex + 1, 
		@RowEnd = @RowStart + @PageSize - 1

	SELECT A.*
	FROM
		(
		SELECT
			ROW_NUMBER() OVER (ORDER BY d.TransDate ASC) AS RowNum,
			d.SportType,
			d.TransId,
			d.BetId,
			d.BetType,
			d.Hdp1,
			d.Hdp2,
			d.MOdds,
			d.OddsType,
			d.Odds,
			d.Stake * ISNULL(e.Rate, 1) AS Stake,
			d.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
			d.BetTeam,
			d.Status,
			d.SettlementStatus,
			d.RefNo,
			d.TransDate,
			d.WinLostDate,
			d.WinLost * ISNULL(e.Rate, 1) AS WinLost,
			d.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
			d.Comm * ISNULL(e.Rate, 1) AS Comm,
			d.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
			d.LiveIndicator,
			d.LiveHomeScore,
			d.LiveAwayScore,
			d.Ip,
			d.LeagueId,
			d.MatchId,
			d.MatchCode,
			d.Race,
			d.EventDate,
			d.HomeId,
			d.AwayId,
			d.BetStatus,
			d.IsNeutral,
			d.VirtualRate,
			d.IsShowOTExRate,
			d.Currency,
			d.ShowTime,
			d.BetCheck,
			d.TransDesc,
			d.BetdaqId,
			d.ExtraInfo,
			d.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
			d.OriginalBetType,
			d.WalletType,
			d.RefCode,
			d.OddsSpread,
			d.SiteId
		FROM @BetListByDateMem AS d
			LEFT JOIN @ExchangeRate AS e ON d.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	-- Get sub tickets
	DECLARE @BettransDetail TABLE(
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	)

	-- Virtual Sports
	IF EXISTS (	SELECT 1
				FROM @BetListByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 5 AND sbt.EventType = 3)
	BEGIN
		IF @tdate > @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake * ISNULL(e.Rate, 1) AS Stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS b ON bm.refno = b.refno
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
				LEFT JOIN @ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtm.ProductID = 5
				AND sbtm.EventType = 3
		END

		IF @fdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake * ISNULL(e.Rate, 1) AS Stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS b ON bm.refno = b.refno
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
				LEFT JOIN @ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtm.ProductID = 5
				AND sbtm.EventType = 3
		END

		IF @fdate < @BalanceUpDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake * ISNULL(e.Rate, 1) AS Stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam
			FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS b ON bm.refno = b.refno
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
				LEFT JOIN @ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtm.ProductID = 5
				AND sbtm.EventType = 3
		END
	END

	SELECT DISTINCT * FROM @BettransDetail
	ORDER BY RefNo ASC, Bettype ASC
END
GO
