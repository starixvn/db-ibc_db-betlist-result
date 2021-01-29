/*<info serverAlias="DBARC-bodb_Archive" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelWinLossByDate_Mem_Old]
	@CustId					INT,
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@ProductIds				VARCHAR(MAX),
	@ProductDetails			VARCHAR(MAX)	= '',
	@ShowProgressiveBonus	BIT				= 0
AS

/*
	Created: 20090122@[creator]
	Task: get settled tickets by member
	DB: DBARC.bodb_Archive
	Original: BetsSelMWinLoss

	Revisions:
		- 20070205@[Thien]: Always get data from bettrans and bettrans14
		- 20080401@[Thien]: Remove @GetOldData
		- 20080417@[Phuc]: Add matchid
		- 20080620@[Thien]: Add betstatus
		- 20080629@[Viet]: remove UNION, uses temporary table instead, Remove Teamname, Leaguename, Sportname, TypeName also.
		- 20080805@[Thien]: - Remove DB06.DBARC.bodb_archive.dbo.bettrans_bk, separate to new DB.
							- Remove temp Table Also
							- Add @MoveBetsDay
		- 20081106@[VinhTring]: Get more result(Sporttype: Horseracing) for betlist
		- 20090226@[HiepVo]: Get more result for Casino Integration
		- 20090321@[HiepVo]: Include Refno, BetID for casino
		- 20090401@[Hanh]: fix bet status of the refund match
		- 20090402@[Phuc]: add indexname
		- 20090407@[HanhVu]: remove redundant transid field
		- 20090409@[HiepVo]: remove condition bettrans_bk.status of Casino
		- 20090411@[HiepVo]: Insert column BetID to table: @BetListByDateMem
		- 20090416@Minh: remove indexName
		- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@HiepVo: Change formula of commission
		- 20090522@HiepVo: More filter: ShowHR, ShowFI. Add F.O Horse Racing bet type (split Sport Book);Get more data from bettransm for HR
		- 20090708@[Hanh]: order by RefNo, bettype from bettransM table.
		- 20090710@Phuc: unhide IP for TB currency.
		- 20090930@Phuc: Show the refunded tickets' status based on bettrans.status
		- 20091003@[MinhNguyen]: get oddstype
		- 20091024@[MinhNguyen]: get modds, finalodds
		- 20091116@Theo: using bettrans_bk to join in outright_bk instead og outright14
		- 20100611@Henry: For mix-parlay, match value is either 0 OR 9
		- 20100902@Kiwi: Add Number Game & IBCBet Bingo
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110408@Lukas: change Param @ShowHR -> @ShowRB
		- 20110408@Amy: Change function to get Odds value and showed odds type
						Show odds value and odds type for Number game
		- 20110518@Henry: record custid to @BetListByDateMem
		- 20110518@Johnson: change column bettype int temporary table to smallint
		- 20110801@Sophia: change the range of number game's bettype from 81 to 120,add new bettype 29 for Combination Mix parlay
		- 20110809@Sophia: Not to use function f_GetChoice to get betteam (bettype <> 14, 16)
		- 20110811@Sophia: Add new columns actual_stake
		- 20111123@Jamie: Remove check @Today 
		- 201112107@Sophia: Change the sportsbook of P2P to 253
		- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
		- 20120109@Jamie: Exclude bettype 10 ( Outright) when joining in match table
		- 20120119@Sophia: Add showtime for Table - Shoe - Hand of LiveCasino
						   Add Sub table for Live Casino
		- 20120330@Lukas: fix bug - duplicate tickets between soccer & racing (matchid & orid are the same values)
		- 20120419@Lukas: Show transid of main ticket for subticket of system parlay
		- 20120502@Johnson: Get session id(betcheck) for bets list P2P
		- 20120629@Sophia: Show hdp1 for Number game
		- 20120803@Jamie: Remove PRIMARY KEY ON TransID because TransID for system parlay of Sub-tickets shown as Main TICKETS
		- 20120807@Sophia: Add new parametter @showVS for Virtual Sports (sporttype = 180 for representing)
						- Remove Financial product
		- 20120927@Sophia: Get comstatus
		- 20130225@Elodie: Add bet list of Virtual Horse Racing
		- 20130226@Lukas: move SP to bodb_archive
		- 20130820@Kathy: Apply Progressive Bonus: bettype 72 for Casino
		- 20140306@Patrick: Add more Keno product
		- 20140310@Patrick: Exclude keno from Sportbook
		- 20140414@Dom: change to odds for VS
		- 20140907@Dom: [Redmine #22012] remove duplicate VS transaction id in bet list feature
		- 20141103@Dom: Apply sport bettype matrix
		- 20150302@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217
		- 20150522@Bobby: Add GD product
		- 20150526@Bobby: Implement bet list core
		- 20150706@Bobby: #39097 - Fixing bug for showing Keno's bettype info
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150828@Kos: Support Colossus Bet
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20151217@Kos: Support Cockfighting [#Redmine: 48850]
		- 20160215@Kos: Support AllBet [#Redmine: 50864]
		- 20160331@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160712@Kos: Change to use inline function for SportBettypeMatrix
		- 20160715@Kos: Hide data for specific accounts [#Redmine: 60767]
		- 20160811@Kos: Support NG2
		- 20161101@Kos: Support Fishing World [#Redmine: 65934]
		- 20170327@Kos: Change input params for Microsite bet list [#Redmine: 66992]
					- Support Betradar Virtual Sports [#Redmine: 77280]
		- 20190710@Kos: Rewrite SP, not to use core anymore [#Redmine: 121271]
					- Don't support bettype 71, 72 anymore
					- Remove param @Language, @Error, @ErrorMsg
					- Don't return TPositiontaking, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore, Placing anymore
		- 20191127@Kos: Hotfix - Oddsspread data type [Redmine: #124483]
		- 20191128@Kos: Support Spadegaming [Redmine: #122140]
		- 20191218@Kos: Support Virtual Games [Redmine: #124759]
		- 20200301@Kos: Support SA Gaming [Redmine: #122140]
		- 20200324@Kos: Support Sexy Gaming [Redmine: #130680]
		- 20200331@Kos: Support Saba.club [Redmine: #130769]
		- 20200402@Kos: Support Table Game [Redmine: #129433]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200513@Kos: Support IBCBet Live Casino [Redmine: #130688]
		- 20200514@Kos: Support BBIN [Redmine: #131362]
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

	DECLARE @Data TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetId			BIGINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsId			INT,
		OddsType		TINYINT,
		Odds			MONEY,
		MOdds			MONEY,
		OddsSpread		MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		PlayerComm		MONEY,
		Comm			MONEY,
		AComm			MONEY,
		SComm			MONEY,
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		ADiscount		SMALLMONEY,
		MDiscount		SMALLMONEY,
		SDiscount		SMALLMONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(15),
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(20),
		EventDate		DATETIME,
		HomeId			INT,
		AwayId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		ComStatus		NVARCHAR(20),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		Product			VARCHAR(30)
	);

	DECLARE @DetailData TABLE (
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

	-- Check if customer is belong to specific line to hide data
	DECLARE @Srecommend	INT,
		@LoginName		NVARCHAR(128)

	SELECT @Srecommend = srecommend
	FROM bodb02.dbo.custInfo WITH (NOLOCK)
	WHERE custid = @CustId

	IF EXISTS ( SELECT 1 FROM bodb02.dbo.f_SpecialSuper() WHERE Srecommend = @Srecommend )
	BEGIN
		SELECT @LoginName = SUSER_NAME()

		IF @FromDate < '2016-06-01' AND @LoginName <> 'bodbDownlineNetView'		-- acc internal login 
			SELECT @FromDate = '2016-06-01'
	END

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	SET @TempFromDate = @FromDate
	SET @TempToDate = @ToDate

	INSERT INTO @Data (
		TransId,
		RefNo,
		CustId,
		BetType,
		BetId,
		BetTeam,
		Hdp1,
		Hdp2,
		OddsId,
		OddsType,
		Odds,
		MOdds,
		OddsSpread,
		Stake,
		Actual_Stake,
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
		ADiscount,
		MDiscount,
		SDiscount,
		Status,
		TransDate,
		WinLostDate,
		LiveIndicator,
		LiveHomeScore,
		LiveAwayScore,
		Ip,
		MatchId,
		BetCheck,
		ComStatus,
		TransDesc,
		BetdaqId,
		ExtraInfo)
	SELECT
		b.transid,
		b.refno,
		b.custid,
		b.bettype,
		ISNULL(b.betid, 0) AS BetId,
		b.betteam,
		b.hdp1,
		b.hdp2,
		b.oddsid,
		b.oddstype,
		b.odds,
		b.modds,
		b.oddsspread,
		b.stake,
		b.actual_stake,
		b.winlost,
		b.awinlost,
		b.mwinlost,
		b.swinlost,
		b.playercomm,
		b.comm,
		b.acomm,
		b.scomm,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,
		b.discount,
		b.adiscount,
		b.sdiscount,
		b.status,
		b.transdate,
		b.winlostdate,
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.ip,
		b.matchid,
		b.betcheck,
		b.comstatus,
		b.transdesc,
		b.betdaqid,
		b.ExtraInfo
	FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
	WHERE b.custid = @CustId
		AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate

	IF EXISTS (SELECT 1 FROM @Data)
	BEGIN
		-- Get Betradar Virtual Sports in addition to Virtual Sports
		SET @ProductIds = bodb02.dbo.f_AddRelatedProducts(@ProductIds)

		IF @ShowProgressiveBonus = 1 SET @ProductIds += ',6' -- duplicate values is ok

		-- Gather BettypeMatrix
		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

		INSERT INTO @SportBettype
		SELECT ProductID, BetType, EventType
		FROM bodb02.dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest)

		UPDATE b
		SET
			Product = CASE
						WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'	-- Sportsbook Parlay
						WHEN s.ProductID = 6 THEN 'OneRNG'	-- RNG Casino
						WHEN s.ProductID = 8 THEN 'Keno'
						WHEN s.ProductID = 12 THEN 'GD'		-- Gold Deluxe
						WHEN s.ProductID = 21 THEN 'AllBet'
						WHEN s.ProductID = 22 THEN 'VB'		-- Macau Games
						WHEN s.ProductID = 23 THEN 'NG2'
						WHEN s.ProductID = 24 THEN 'FW'		-- Fishing World
						WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2' --Betradar Virtual Sports Parlay
						WHEN s.ProductID = 28 THEN 'Lottery'
						WHEN s.ProductID = 32 THEN 'PP'		-- Pragmatic Play Casino
						WHEN s.ProductID = 34 THEN 'CC'		-- Card Club
						WHEN s.ProductID = 36 THEN 'SG'		-- Spadegaming
						WHEN s.ProductID = 38 THEN 'VRG'	-- Virtual Games
						WHEN s.ProductID = 39 THEN 'SAG'	-- SA Gaming
						WHEN s.ProductID = 40 THEN 'TG'		-- Table Games
						WHEN s.ProductID = 42 THEN 'SBC'	-- Saba.club
						WHEN s.ProductID = 45 THEN 'SXG'	-- Sexy Gaming
						WHEN s.ProductID = 46 THEN 'IBCLC'	-- IBCBet Live Casino
						WHEN s.ProductID = 47 THEN 'BBIN'	-- BBIN
						WHEN s.ProductID = 49 THEN 'VS3'	-- Leap Gaming Virtual Sports 3
						WHEN s.ProductID = 50 THEN 'RNGW'	-- RNG War
						WHEN s.ProductID = 51 THEN 'WM'		-- WM
						WHEN s.ProductID = 52 THEN 'ION'	-- ION
						WHEN s.ProductID = 55 THEN 'PGS'	-- PG Soft
						WHEN s.ProductID = 56 THEN 'JK'		-- Joker
						WHEN s.ProductID = 57 THEN 'BG'		-- Big Gaming
						WHEN s.ProductID = 59 THEN 'GDG'	-- GDG
						WHEN s.ProductID = 60 THEN 'MXG'	-- MaxGame
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'		-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'		-- Number Game
						WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'	-- Number Game - Happy 5 Linked Games
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'		-- Virtual Sports:: sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'	-- Betradar Virtual Sports
						WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
						WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'		-- Virtual sports:: racing
						ELSE 'Unknown'
					END
		FROM @Data AS b
			INNER JOIN @SportBettype AS s ON b.BetType = s.BetType

		DELETE @Data
		WHERE Product = 'Unknown'
			OR Product IS NULL
			OR BetType IN (71, 72)

		IF EXISTS (SELECT 1 FROM @Data)
		BEGIN
			UPDATE b
			SET
				TransId = CASE
							WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
							ELSE b.transid
						END,
				SportType = CASE
								WHEN b.Product IN ('OneRNG', 'CC', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'SXG', 'IBCLC', 'BBIN', 'RNGW', 'ION', 'PGS', 'JK', 'WM', 'GDG', 'VS3', 'BG', 'H5LG', 'MXG') THEN b.matchid		-- ONERnG, Card Club, Spadegaming
								WHEN b.Product = 'Keno' THEN 202	-- Keno
								WHEN b.Product = 'Lottery' THEN 220	-- Lottery
								WHEN b.Product = 'GD' THEN 255		-- Gold Deluxe
								WHEN b.Product = 'AllBet' THEN 211	-- AllBet
								WHEN b.Product = 'VB' THEN 212		-- Macau Games
								WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
								WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
								WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
								WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
								WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
								WHEN b.Product = 'FW' THEN 219		-- Fishing World
								WHEN b.Product = 'PP' THEN 248		-- Pragmatic Casino
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.sporttype
								WHEN b.Product IN ('Outright') THEN l.sporttype
								WHEN b.Product IN ('VR') THEN vr.SportType
								ELSE 0
							END,
				BetTeam = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2') THEN b.betteam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2') THEN b.hdp1
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN b.Product IN ('SB', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2') THEN b.hdp2
							ELSE 0
						END,
				OddsType = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.oddstype
								ELSE 0
							END,
				Odds = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'OneRNG', 'PP', 'Keno', 'GD', 'NG2', 'ParlayVS2', 'Lottery', 'VRG', 'TG', 'VS3') THEN b.odds
							ELSE 0
						END,
				MOdds = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2') THEN b.modds
							ELSE 0
						END,
				WinLost = b.winlost - b.actual_stake,
				Comm = b.Comm - b.PlayerComm,
				AComm = b.AComm - b.Comm,
				SComm = b.SComm - b.AComm,
				Status = CASE
							WHEN b.Product = 'TG' AND b.Status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
							WHEN b.Product = 'TG' AND b.Status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
							ELSE b.Status
						END,
				LiveIndicator = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveindicator
									ELSE 0
								END,
				LiveHomeScore = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'NG2') THEN b.livehomescore
									ELSE 0
								END,
				LiveAwayScore = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR') THEN b.liveawayscore
									ELSE 0
								END,
				LeagueId = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.leagueid
								WHEN b.Product IN ('Outright') THEN o.leagueid
								WHEN b.Product IN ('VR') THEN vr.LeagueID
								ELSE 0
							END,
				MatchId = CASE
								WHEN b.Product IN ('GD') THEN 255
								WHEN b.Product IN ('NG2') THEN b.betdaqid
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchid
								WHEN b.Product IN ('Outright') THEN o.orid
								WHEN b.Product IN ('VR') THEN b.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchcode
								WHEN b.Product IN ('Outright') THEN o.matchcode
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
								ELSE ''
							END,
				Race = CASE
							WHEN b.Product IN ('Outright') THEN o.groupmatch
							WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
							ELSE ''
						END,
				EventDate = CASE
								WHEN b.Product IN ('SB') THEN m.GlobalShowTime
								WHEN b.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
								WHEN b.Product IN ('Outright') THEN o.eventdate
								WHEN b.Product IN ('VR') THEN vo.EventDate
								ELSE b.winlostdate
							END,
				HomeId = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.homeid
							WHEN b.Product IN ('Outright') THEN o.teamid
							WHEN b.Product IN ('VR') THEN vo.RacerID
							ELSE 0
						END,
				AwayId = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.awayid
							ELSE 0
						END,
				BetStatus = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.betstatus
									ELSE ''
								END,
				IsNeutral = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
								ELSE 0
							END,
				ShowTime = CASE
								WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
								WHEN b.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
								ELSE ''
							END,
				BetCheck = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'ParlayVS2', 'GD', 'VRG', 'H5LG') THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
								ELSE ''
							END,
				ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
				TransDesc = CASE
								WHEN b.Product IN ('SB', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'FW', 'Lottery', 'PP', 'VRG', 'TG', 'PGS', 'JK', 'VS3', 'H5LG')
									THEN ISNULL(b.transdesc, '')
								ELSE ''
							END,
				OddsSpread = CASE
								WHEN b.Product IN ('SB', 'OneRNG', 'PP') THEN ISNULL(b.oddsspread, 0)
								ELSE 0
							END,
				BetdaqId = -1,
				ExtraInfo = CASE
								WHEN b.Product IN ('SB', 'VS3', 'Parlay') THEN ISNULL(b.ExtraInfo, '')
								ELSE ''
							END
			FROM @Data AS b
				LEFT JOIN dbo.match_bk AS m WITH (NOLOCK) ON b.Product IN ('SB', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
				LEFT JOIN dbo.outright_bk AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
				LEFT JOIN dbo.VSOutright_bk AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
				LEFT JOIN dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID

			-- Get ticket detail
			-- Virtual Sports Racing
			INSERT INTO @DetailData
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.mpositiontaking,
				bm.spositiontaking,
				bm.bettype,
				bm.betteam,
				'' AS TransDesc
			FROM @Data AS c
				INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON c.RefNo = bm.refno
			WHERE c.Product = 'VR' AND bm.custid = @CustId
	
			UNION ALL -- Gold Deluxe
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.mpositiontaking,
				bg.spositiontaking,
				bg.bettype,
				bg.betteam,
				bg.transdesc
			FROM @Data AS c
				INNER JOIN dbo.bettransg AS bg WITH (NOLOCK) ON c.TransId = bg.refno
			WHERE c.Product = 'GD' AND bg.custid = @CustId
		END
	END

	-- Get currency name
	DECLARE @CurrencyName	NVARCHAR(50),
		@Username		NVARCHAR(50)

	SELECT
		@Username = c.username,
		@CurrencyName = ex.currency
	FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Exchange AS ex WITH (NOLOCK) ON ex.exchangeid = c.currency
	WHERE c.custid = @CustId

	-- Filter due to product detail
	IF EXISTS (SELECT 1 FROM @Data WHERE Product IN ('PP'))
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
		FROM bodb02.dbo.f_GetProductDetail()

		DELETE b
		FROM @Data AS b
		WHERE b.Product = 'PP'
			AND NOT EXISTS (SELECT 1 FROM @ProductDetail
							WHERE ProductId = 32 AND BetType = b.BetType)
			AND EXISTS (SELECT 1 FROM @FullProductDetail
							WHERE ProductId = 32 AND BetType = b.BetType)

		DELETE b
		FROM @Data AS b
		WHERE b.Product = 'PP'
			AND NOT EXISTS (SELECT 1 FROM @ProductDetail
							WHERE ProductId = 32 AND BetType = 0)
			AND NOT EXISTS (SELECT 1 FROM @FullProductDetail
							WHERE ProductId = 32 AND BetType = b.BetType)
	END

	SELECT
		b.TransId,
		b.RefNo,
		b.CustId,
		b.SportType,
		b.BetType,
		b.BetId,
		b.BetTeam,
		b.Hdp1,
		b.Hdp2,
		b.OddsId,
		b.OddsType,
		b.Odds,
		b.MOdds,
		b.OddsSpread,
		b.Stake,
		b.Actual_Stake,
		b.WinLost,
		b.AWinLost,
		b.MWinLost,
		b.SWinLost,
		b.PlayerComm,
		b.Comm,
		b.AComm,
		b.SComm,
		b.APositionTaking,
		b.MPositionTaking,
		b.SPositionTaking,
		b.ADiscount,
		b.MDiscount,
		b.SDiscount,
		b.Status,
		b.TransDate,
		b.WinLostDate,
		b.LiveIndicator,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.Ip,
		b.LeagueId,
		b.MatchId,
		b.MatchCode,
		b.Race,
		b.EventDate,
		b.HomeId,
		b.AwayId,
		b.BetStatus,
		b.IsNeutral,
		b.ShowTime,
		b.BetCheck,
		b.ComStatus,
		b.TransDesc,
		b.BetdaqId,
		b.ExtraInfo,
		@CurrencyName AS Currency,
		@Username AS Username
	FROM @Data AS b
	ORDER BY b.TransId DESC

	SELECT * FROM @DetailData
	ORDER BY RefNo DESC
END
GO


GRANT EXECUTE ON [dbo].[Age_BetList_SelWinLossByDate_Mem_Old] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinLossByDate_Mem_Old] TO [bodbDownlineNetView]
GO
