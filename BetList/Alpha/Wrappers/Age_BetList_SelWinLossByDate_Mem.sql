/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelWinLossByDate_Mem]
	@CustId					INT,
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@Language				VARCHAR(2) = 'E',
	@MoveBetsDay			SMALLDATETIME,
	@ProductIds				VARCHAR(MAX),
	@ShowProgressiveBonus	BIT = 0
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
		- 20110110@Thien: + record more custid from @BetListByDateMem, in order to optimize INNER JOIN with bettransm/bettransm14
						+ index hint for bettransm/bettransm14
		- 20110308@Lukas: change @showHR -> @showRB, add more sporttype 152 & 153
		- 20110408@Amy: Change function to get Odds value and showed odds type
						Show odds value and odds type for Number Game
		- 20110518@Johnson: change bettype,sporttype columns in temporary table to smallint
		- 20110801@Sophia: change the range of number game's bettype from 81 to 120, add new bettype 29 for Combination Mix parlay
		- 20110809@Sophia: Not to use function f_GetChoice to get betteam (bettype <> 14, 16)
		- 20110811@Sophia: Add new columns actual_stake and modds
		- 20111207@Sophia: Change the sportsbook of P2P to 253
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice , f_ShowOddsByBettype
		- 20120120@Sophia:  Add showtime for Table - Shoe - Hand of LiveCasino
							Add Sub table for Live Casino
		- 20120419@Lukas: Show transid of main ticket for subticket of system parlay
		- 20120502@Johnson: Get session id(betcheck) for bets list P2P
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Show hdp1 for Number game
		- 20120807@Sophia:  . Add new parametter @showVS for Virtual Sports (sporttype = 180 for representing)
							. Remove Financial product
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
		- 20180921@Kos: Support Gold Deluxe - SicBo & BidMe [#Redmine: 101690]
*/

BEGIN
	SET NOCOUNT ON;

	-- Get Betradar Virtual Sports in addition to Virtual Sports
	SET @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)

	-- Check SP Version
	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	IF @ShowProgressiveBonus = 1 SET @ProductIds += ',6' -- duplicate values is ok

	DECLARE @f_date SMALLDATETIME
	DECLARE @t_date SMALLDATETIME
	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

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
		, Ip				NVARCHAR(15)
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
		, OddsSpread		SMALLMONEY
		, BetdaqId			BIGINT
		, ExtraInfo			VARCHAR(1000)
		, Currency			NVARCHAR(50)
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
		, OddsSpread		SMALLMONEY
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
							WHEN s.EventType = 0 AND ProductID = 1 THEN 'Parlay' -- Sportsbook Parlay
							WHEN s.EventType = 0 AND ProductID = 6 THEN 'OneRNG' -- RNG Casino
							WHEN s.EventType = 0 AND ProductID = 8 THEN 'Keno'
							WHEN s.EventType = 0 AND ProductID = 12 THEN 'GD' --Gold Deluxe
							WHEN s.EventType = 0 AND ProductID = 15 THEN 'CB' --Colossus Bet
							WHEN s.EventType = 0 AND ProductID = 21 THEN 'AllBet'
							WHEN s.EventType = 0 AND ProductID = 22 THEN 'VB' --Macau Games
							WHEN s.EventType = 0 AND ProductID = 23 THEN 'NG2'
							WHEN s.EventType = 0 AND ProductID = 24 THEN 'FW' --Fishing World
							WHEN s.EventType = 0 AND ProductID = 27 THEN 'ParlayVS2' --Betradar Virtual Sports Parlay
							WHEN s.EventType = 0 AND ProductID = 28 THEN 'Lottery'
							WHEN s.EventType = 0 AND ProductID = 32 THEN 'PP' --Pragmatic Play Casino
							WHEN s.EventType = 0 AND ProductID = 33 THEN 'PG' --Poker Games
							WHEN s.EventType = 1 AND ProductID = 1 THEN 'SB' --Sportsbook
							WHEN s.EventType = 1 AND ProductID = 3 THEN 'NG' --Number Game
							WHEN s.EventType = 1 AND ProductID = 5 THEN 'VS' --Virtual Sports:: sportsbook
							WHEN s.EventType = 1 AND ProductID = 26 THEN 'Lucky3' -- NG Lucky3
							WHEN s.EventType = 1 AND ProductID = 27 THEN 'VS2' --Betradar Virtual Sports
							WHEN s.EventType = 2 AND ProductID = 1 THEN 'Outright'
							WHEN s.EventType = 3 AND ProductID = 5 THEN 'VR' -- virtual sports:: racing
							WHEN s.EventType = 5 AND ProductID = 30 THEN 'BF' --Bullfighting
							ELSE 'unknown'
						END
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) AS s ON b.bettype = s.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @f_date AND @t_date
			AND 1 = CASE
						WHEN b.statusID > 1 THEN 1
						WHEN s.ProductID IN (21, 22, 24, 32) OR (s.ProductID = 6 AND s.SubProduct <> '') THEN 1 -- don't care status of casino's summary rows.
						ELSE 0
					END

		IF @@ROWCOUNT > 0
		BEGIN
			IF EXISTS (SELECT 1 FROM @Tickets WHERE Product IN ('VB', 'FW', 'PP', 'OneRNG') AND WinLostDate >= @Yesterday) -- bettransRnG
			BEGIN
				INSERT INTO @temp_bettransX
				SELECT RefNo = c.transid
					,Odds = CASE
								WHEN Product = 'OneRNG' THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
								ELSE 0 END
					,Stake = SUM(brng.stake)
					,actual_stake = SUM(brng.actual_stake)
					,Status = CASE
									WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
									WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
									ELSE 'Draw' END
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
					,OddsSpread = CASE WHEN c.Product IN ('OneRNG') THEN ISNULL(SUM(brng.BetStake), 0) ELSE 0 END
				FROM @Tickets AS c
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.transid
				WHERE c.Product IN ('VB', 'FW', 'PP', 'OneRNG')
					AND c.WinLostDate >= @Yesterday
					AND brng.statusID NOT IN (0, 1)
				GROUP BY c.transid, c.Product
			END -- end: bettransRnG

			IF EXISTS (SELECT 1 FROM @Tickets WHERE Product = 'Allbet' AND WinLostDate >= @Yesterday) -- bettransLC
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
				WHERE c.Product = 'Allbet'
					AND c.WinLostDate >= @Yesterday
					AND blc.statusID NOT IN (0, 1)
				GROUP BY c.transid, c.Product
			END -- end: bettransLC

			INSERT INTO #MemBetTicket
			SELECT TransId = CASE
								WHEN c.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END 
				,RefNo = b.refno
				,CustId = b.custid
				,Username = b.username
				,SportType = CASE
								WHEN c.Product = 'OneRNG' THEN b.matchid
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
								WHEN c.Product = 'PG' THEN 163 -- Poker Games
								WHEN c.Product = 'CB' THEN 204 --Colossus Bet
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.sporttype
								WHEN c.Product IN ('Outright') THEN l.sporttype
								WHEN c.Product IN ('VR') THEN vr.SportType
								WHEN c.Product IN ('BF') THEN m3.SportType
								ELSE 0
							END -- parlay(s)
				,BetType = b.bettype
				,BetId = ISNULL(b.betid, 0)
				,BetTeam = CASE 
								WHEN c.Product IN ('Parlay', 'ParlayVS2') THEN b.Betteam
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.betteam
								WHEN c.Product IN ('BF') THEN b.betteam
								ELSE ''	END 
				,Hdp1 = CASE 
							WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2', 'PG') THEN b.hdp1 -- parlay(s), NG2, Pokergames
							WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.hdp1
							WHEN c.Product IN ('VR') THEN b.hdp1
							WHEN c.Product IN ('BF') THEN b.hdp1
							ELSE 0 END
				,Hdp2 = CASE 
							WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp2 --parlay(s), NG2
							WHEN c.Product IN ('SB', 'VS', 'VS2') THEN b.hdp2
							WHEN c.Product IN ('VR') THEN b.hdp2
							ELSE 0 END
				,OddsType = CASE 
								WHEN c.Product IN ('Keno') THEN b.OddsType -- Keno
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.oddstype
								WHEN c.Product IN ('BF') THEN b.oddstype
								ELSE 0 END
				,OddsId = CASE
								WHEN c.Product IN ('BF') THEN 0
								ELSE b.oddsid END
				,Odds = CASE 
							WHEN c.Product IN ('Parlay', 'OneRNG', 'Keno', 'GD', 'NG2', 'ParlayVS2', 'Lottery') THEN b.Odds
							WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.Odds IS NOT NULL THEN x.Odds
							WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.odds
							WHEN c.Product IN ('Outright') THEN b.odds
							WHEN c.Product IN ('VR') THEN b.odds
							WHEN c.Product IN ('BF') THEN b.odds
							ELSE 0 END
				,MOdds = CASE 
							WHEN c.Product IN ('Parlay', 'ParlayVS2')  THEN b.modds 
							WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.modds
							WHEN c.Product IN ('Outright') THEN b.modds
							WHEN c.Product IN ('VR') THEN b.modds
							ELSE 0 END
				,Stake = CASE
							WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.Stake IS NOT NULL THEN x.Stake
							ELSE b.stake END
				,Actual_Stake = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.Actual_Stake IS NOT NULL THEN x.Actual_Stake
								ELSE b.actual_stake END
				,Status = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.status IS NOT NULL THEN x.status
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') 
									AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								ELSE b.status END
				,TransDate = b.transdate
				,WinLostDate = b.winlostdate
				,WinLost = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.WinLost IS NOT NULL THEN x.WinLost
								ELSE b.winlost - b.actual_stake END
				,AWinLost = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.AWinLost IS NOT NULL THEN x.AWinLost
								ELSE b.awinLost END
				,MWinLost = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.MWinLost IS NOT NULL THEN x.MWinLost
								ELSE b.mwinLost END
				,SWinLost = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.SWinLost IS NOT NULL THEN x.SWinLost
								ELSE b.SwinLost END
				,PlayerComm = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.PlayerComm IS NOT NULL THEN x.PlayerComm
								ELSE b.playercomm END
				,Comm = CASE
							WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.Comm IS NOT NULL THEN x.Comm
							ELSE b.comm - b.playercomm END
				,AComm = CASE
							WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.AComm IS NOT NULL THEN x.AComm
							ELSE b.acomm - b.comm END
				,SComm = CASE
							WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.SComm IS NOT NULL THEN x.SComm
							ELSE b.scomm - b.acomm END
				,APositionTaking = CASE
										WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.APositiontaking IS NOT NULL THEN x.APositiontaking
										ELSE b.APositiontaking END
				,MPositionTaking = CASE
										WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.MPositiontaking IS NOT NULL THEN x.MPositiontaking
										ELSE b.MPositiontaking END
				,SPositionTaking = CASE
										WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.SPositiontaking IS NOT NULL THEN x.SPositiontaking
										ELSE b.SPositiontaking END
				,TPositionTaking = CASE
										WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.TPositiontaking IS NOT NULL THEN x.TPositiontaking
										ELSE b.TPositiontaking END
				,ADiscount = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.discount IS NOT NULL THEN x.discount
								WHEN c.Product IN ('Lucky3') THEN 0
								ELSE b.discount END
				,MDiscount = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.adiscount IS NOT NULL THEN x.adiscount
								WHEN c.Product IN ('Lucky3') THEN 0
								ELSE b.adiscount END
				,SDiscount = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.sdiscount IS NOT NULL THEN x.sdiscount
								WHEN c.Product IN ('Lucky3') THEN 0
								ELSE b.sdiscount END	
				,LiveIndicator = CASE 
									WHEN c.Product IN ('Parlay') THEN b.Liveindicator 
									WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.liveindicator
									WHEN c.Product IN ('BF') THEN b.liveindicator
									ELSE 0 END
				,LiveHomeScore = CASE 
									WHEN c.Product IN ('Parlay', 'NG2', 'PG') THEN b.Livehomescore 
									WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.livehomescore
									WHEN c.Product IN ('Outright') THEN b.livehomescore
									WHEN c.Product IN ('VR') THEN b.livehomescore
									ELSE 0 END
				,LiveAwayScore = CASE 
									WHEN c.Product IN ('Parlay') THEN b.Liveawayscore 
									WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.liveawayscore
									WHEN c.Product IN ('Outright') THEN b.liveawayscore
									WHEN c.Product IN ('VR') THEN b.liveawayscore
									ELSE 0 END
				,FinalHomeScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.finalhomescore
										ELSE 0 END
				,FinalAwayScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.finalawayscore
										ELSE 0 END
				,HtHomeScore = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.hthomescore
									ELSE 0 END
				,HtAwayScore = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.htawayscore
									ELSE 0 END
				,Ip = b.ip
				,LeagueId = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.leagueid
								WHEN c.Product IN ('Outright') THEN o.leagueid
								WHEN c.Product IN ('VR') THEN vr.LeagueID
								WHEN c.Product IN ('BF') THEN m3.League3rdId
								ELSE 0 END
				,MatchId = CASE
								WHEN c.Product IN ('GD') THEN 255
								WHEN c.Product IN ('NG2') THEN b.betdaqid
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.matchid
								WHEN c.Product IN ('Outright') THEN o.orid
								WHEN c.Product IN ('VR') THEN b.matchid
								WHEN c.Product IN ('BF') THEN m3.Match3rdId
								ELSE 0 END
				,MatchCode = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.matchcode
								WHEN c.Product IN ('Outright') THEN o.matchcode
								WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
								WHEN c.Product IN ('BF') THEN m3.MatchNo
								ELSE '' END
				,Race = CASE
								WHEN c.Product IN ('Outright') THEN o.groupmatch
								WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE '' END
				,EventDate = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.eventdate
								WHEN c.Product IN ('Outright') THEN o.eventdate
								WHEN c.Product IN ('VR') THEN vo.EventDate
								WHEN c.Product IN ('BF') THEN m3.EventDate
								ELSE b.winlostdate END
				,HomeId = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.homeid
								WHEN c.Product IN ('Outright') THEN o.teamid
								WHEN c.Product IN ('VR') THEN vo.RacerID
								WHEN c.Product IN ('BF') THEN m3.HomeId
								ELSE 0 END
				,AwayId = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.awayid
								WHEN c.Product IN ('Outright') THEN 0
								WHEN c.Product IN ('BF') THEN m3.AwayId
								ELSE 0 END
				,BetStatus = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.betstatus
								ELSE '' END
				,IsNeutral = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN ISNULL(m.IsNeutral, 0)
								ELSE 0 END
				,Placing = CASE
								WHEN c.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
								ELSE '' END
				,ShowTime = CASE
								WHEN c.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
								WHEN c.Product IN ('SB', 'NG', 'Lucky3') THEN ISNULL(m.showtime, '')
								WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
								ELSE '' END
				,BetCheck = CASE 
								WHEN c.Product IN ('GD') THEN ISNULL(b.betcheck, '')
								WHEN c.Product IN ('Parlay', 'ParlayVS2', 'PG') THEN ISNULL(b.betcheck, '')
								WHEN c.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
								WHEN c.Product IN ('CB') THEN ISNULL(bm.betcheck, '')
								WHEN c.Product IN ('SB') AND b.bettype IN (216, 217) THEN ISNULL(b.betcheck, '')
								WHEN c.Product IN ('BF') THEN ISNULL(b.betcheck, '')
								ELSE '' END
				,ComStatus = CASE
								WHEN c.Product IN ('PG') THEN ISNULL(b.comstatus, '')
								ELSE CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END END
				,TransDesc = CASE
								WHEN c.Product IN ('OneRNG', 'Keno', 'VB', 'NG2', 'FW', 'Lottery', 'PP') THEN b.transdesc
								WHEN c.Product IN ('SB', 'Lucky3', 'VS2') THEN ISNULL(b.transdesc, '')
								WHEN c.Product IN ('BF') THEN ISNULL(b.transdesc, '')
								ELSE '' END
				,OddsSpread = CASE
								WHEN c.Product IN ('OneRNG') THEN ISNULL(b.oddsspread, 0)
								WHEN c.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
								ELSE 0 END
				,BetdaqId = -1
				,ExtraInfo = CASE
								WHEN c.Product IN ('PG') THEN ISNULL(b.ExtraInfo, '')
								ELSE '' END
				,Currency = b.currencyname
			FROM @Tickets AS c
				INNER JOIN dbo.bettrans AS b WITH(NOLOCK, INDEX=PK_bettrans) ON b.transid = c.transid
				LEFT JOIN dbo.match AS m WITH(NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') AND b.matchid = m.matchid
				LEFT JOIN dbo.bettransm AS bm WITH(NOLOCK) ON c.Product = 'CB' AND bm.refno = b.refno AND bm.bettype = 18001
				LEFT JOIN @temp_bettransX AS x ON c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND c.Winlostdate >= @Yesterday AND x.RefNo = c.transid
				LEFT JOIN dbo.outright AS o WITH(NOLOCK) ON c.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH(NOLOCK) ON c.Product IN ('Outright') AND o.leagueID = l.leagueID
				LEFT JOIN dbo.VSOutright AS vo WITH(NOLOCK) ON c.Product IN ('VR') AND b.oddsid = vo.Orid
				LEFT JOIN dbo.VSRaceInfo AS vr WITH(NOLOCK) ON c.Product IN ('VR') AND vr.EventID = vo.EventID
				LEFT JOIN dbo.Match3rd AS m3 WITH(NOLOCK) ON c.Product IN ('BF') AND b.matchid = m3.Match3rdId

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
		END -- end: @@rowcount > 0
	END
	
	IF @FromDate <= @MoveBetsDay --bettrans14
	BEGIN
		SET @f_date = @FromDate
		SET @t_date = CASE WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END
		
		DELETE FROM @Tickets

		INSERT INTO @Tickets (
			TransID
			,RefNo
			,Product
		)
		SELECT TransID = b.transid
			,RefNo = b.refno
			,Product = CASE
							WHEN s.EventType = 0 AND ProductID = 1 THEN 'Parlay' -- Sportsbook Parlay
							WHEN s.EventType = 0 AND ProductID = 6 THEN 'OneRNG' -- RNG Casino
							WHEN s.EventType = 0 AND ProductID = 8 THEN 'Keno'
							WHEN s.EventType = 0 AND ProductID = 12 THEN 'GD' --Gold Deluxe
							WHEN s.EventType = 0 AND ProductID = 15 THEN 'CB' --Colossus Bet
							WHEN s.EventType = 0 AND ProductID = 21 THEN 'AllBet'
							WHEN s.EventType = 0 AND ProductID = 22 THEN 'VB' --Macau Games
							WHEN s.EventType = 0 AND ProductID = 23 THEN 'NG2'
							WHEN s.EventType = 0 AND ProductID = 24 THEN 'FW' --Fishing World
							WHEN s.EventType = 0 AND ProductID = 27 THEN 'ParlayVS2' --Betradar Virtual Sports Parlay
							WHEN s.EventType = 0 AND ProductID = 28 THEN 'Lottery'
							WHEN s.EventType = 0 AND ProductID = 32 THEN 'PP' --Pragmatic Play Casino
							WHEN s.EventType = 0 AND ProductID = 33 THEN 'PG' --Poker Games
							WHEN s.EventType = 1 AND ProductID = 1 THEN 'SB' --Sportsbook
							WHEN s.EventType = 1 AND ProductID = 3 THEN 'NG' --Number Game
							WHEN s.EventType = 1 AND ProductID = 5 THEN 'VS' --Virtual Sports:: sportsbook
							WHEN s.EventType = 1 AND ProductID = 26 THEN 'Lucky3' -- NG Lucky3
							WHEN s.EventType = 1 AND ProductID = 27 THEN 'VS2' --Betradar Virtual Sports
							WHEN s.EventType = 2 AND ProductID = 1 THEN 'Outright'
							WHEN s.EventType = 3 AND ProductID = 5 THEN 'VR' -- virtual sports:: racing
							WHEN s.EventType = 5 AND ProductID = 30 THEN 'BF' --Bullfighting
							ELSE 'unknown' END
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) AS s ON b.bettype = s.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @f_date AND @t_date
		
		IF @@ROWCOUNT > 0
		BEGIN
			INSERT INTO #MemBetTicket
			SELECT TransId = CASE WHEN c.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid END 
				,RefNo = b.refno
				,CustId = b.custid
				,Username = b.username
				,SportType = CASE
								WHEN c.Product = 'OneRNG' THEN b.matchid
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
								WHEN c.Product = 'PG' THEN 163 -- Poker Games
								WHEN c.Product = 'CB' THEN 204 --Colossus Bet
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.sporttype
								WHEN c.Product IN ('Outright') THEN l.sporttype
								WHEN c.Product IN ('VR') THEN vr.SportType
								WHEN c.Product IN ('BF') THEN m3.SportType
								ELSE 0 END -- parlay(s)
				,BetType = b.bettype
				,BetId = ISNULL(b.betid, 0)
				,BetTeam = CASE
								WHEN c.Product IN ('Parlay', 'ParlayVS2') THEN b.Betteam
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.betteam
								WHEN c.Product IN ('BF') THEN b.betteam
								ELSE ''	END 
				,Hdp1 = CASE
							WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2', 'PG') THEN b.hdp1 -- parlay(s), NG2, Pokergames
							WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.hdp1
							WHEN c.Product IN ('VR') THEN b.hdp1
							WHEN c.Product IN ('BF') THEN b.hdp1
							ELSE 0 END
				,Hdp2 = CASE
							WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp2 --parlay(s), NG2
							WHEN c.Product IN ('SB', 'VS', 'VS2') THEN b.hdp2
							WHEN c.Product IN ('VR') THEN b.hdp2
							ELSE 0 END
				,OddsType = CASE 
								WHEN c.Product IN ('Keno') THEN b.OddsType -- Keno
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.oddstype
								WHEN c.Product IN ('BF') THEN b.oddstype
								ELSE 0 END
				,OddsId = CASE
								WHEN c.Product IN ('BF') THEN 0
								ELSE b.oddsid END
				,Odds = CASE 
							WHEN c.Product IN ('Parlay', 'OneRNG', 'Keno', 'GD', 'NG2', 'ParlayVS2', 'Lottery') THEN b.Odds
							WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.odds
							WHEN c.Product IN ('Outright') THEN b.odds
							WHEN c.Product IN ('VR') THEN b.odds
							WHEN c.Product IN ('BF') THEN b.odds
							ELSE 0 END
				,MOdds = CASE 
							WHEN c.Product IN ('Parlay', 'ParlayVS2')  THEN b.modds 
							WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.modds
							WHEN c.Product IN ('Outright') THEN b.modds
							WHEN c.Product IN ('VR') THEN b.modds
							ELSE 0 END
				,Stake = b.stake
				,Actual_Stake = b.actual_stake
				,Status = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') 
									AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								ELSE b.status END
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
				,ADiscount = CASE
								WHEN c.Product IN ('Lucky3') THEN 0
								ELSE b.discount END
				,MDiscount = CASE
								WHEN c.Product IN ('Lucky3') THEN 0
								ELSE b.adiscount END
				,SDiscount = CASE
								WHEN c.Product IN ('Lucky3') THEN 0
								ELSE b.sdiscount END	
				,LiveIndicator = CASE 
									WHEN c.Product IN ('Parlay') THEN b.Liveindicator 
									WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.liveindicator
									WHEN c.Product IN ('BF') THEN b.liveindicator
									ELSE 0 END
				,LiveHomeScore = CASE 
									WHEN c.Product IN ('Parlay', 'NG2', 'PG') THEN b.livehomescore 
									WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.livehomescore
									WHEN c.Product IN ('Outright') THEN b.livehomescore
									WHEN c.Product IN ('VR') THEN b.livehomescore
									ELSE 0 END
				,LiveAwayScore = CASE 
									WHEN c.Product IN ('Parlay') THEN b.Liveawayscore 
									WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN b.liveawayscore
									WHEN c.Product IN ('Outright') THEN b.liveawayscore
									WHEN c.Product IN ('VR') THEN b.liveawayscore
									ELSE 0 END
				,FinalHomeScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.finalhomescore
										ELSE 0 END
				,FinalAwayScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.finalawayscore
										ELSE 0 END
				,HtHomeScore = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.hthomescore
									ELSE 0 END
				,HtAwayScore = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.htawayscore
									ELSE 0 END
				,Ip = b.ip
				,LeagueId = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.leagueid
								WHEN c.Product IN ('Outright') THEN o.leagueid
								WHEN c.Product IN ('VR') THEN vr.LeagueID
								WHEN c.Product IN ('BF') THEN m3.League3rdId
								ELSE 0 END
				,MatchId = CASE
								WHEN c.Product IN ('GD') THEN 255
								WHEN c.Product IN ('NG2') THEN b.betdaqid
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.matchid
								WHEN c.Product IN ('Outright') THEN o.orid
								WHEN c.Product IN ('VR') THEN b.matchid
								WHEN c.Product IN ('BF') THEN m3.Match3rdId
								ELSE 0 END
				,MatchCode = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.matchcode
								WHEN c.Product IN ('Outright') THEN o.matchcode
								WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
								WHEN c.Product IN ('BF') THEN m3.MatchNo
								ELSE '' END
				,Race = CASE
								WHEN c.Product IN ('Outright') THEN o.groupmatch
								WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE '' END
				,EventDate = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.eventdate
								WHEN c.Product IN ('Outright') THEN o.eventdate
								WHEN c.Product IN ('VR') THEN vo.EventDate
								WHEN c.Product IN ('BF') THEN m3.EventDate
								ELSE b.winlostdate END
				,HomeId = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.homeid
								WHEN c.Product IN ('Outright') THEN o.teamid
								WHEN c.Product IN ('VR') THEN vo.RacerID
								WHEN c.Product IN ('BF') THEN m3.HomeId
								ELSE 0 END
				,AwayId = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.awayid
								WHEN c.Product IN ('Outright') THEN 0
								WHEN c.Product IN ('BF') THEN m3.AwayId
								ELSE 0 END
				,BetStatus = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.betstatus
								ELSE '' END
				,IsNeutral = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN ISNULL(m.IsNeutral, 0)
								ELSE 0 END
				,Placing = CASE
								WHEN c.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
								ELSE '' END
				,ShowTime = CASE
								WHEN c.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
								WHEN c.Product IN ('SB', 'NG', 'Lucky3') THEN ISNULL(m.showtime, '')
								WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
								ELSE '' END
				,BetCheck = CASE 
								WHEN c.Product IN ('GD') THEN ISNULL(b.betcheck, '')
								WHEN c.Product IN ('Parlay', 'ParlayVS2', 'PG') THEN ISNULL(b.betcheck, '')
								WHEN c.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
								WHEN c.Product IN ('CB') THEN ISNULL(bm.betcheck, '')
								WHEN c.Product IN ('SB') AND b.bettype IN (216, 217) THEN ISNULL(b.betcheck, '')
								WHEN c.Product IN ('BF') THEN ISNULL(b.betcheck, '')
								ELSE '' END
				,ComStatus = CASE
								WHEN c.Product IN ('PG') THEN ISNULL(b.comstatus, '')
								ELSE CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END END
				,TransDesc = CASE
								WHEN c.Product IN ('OneRNG', 'Keno', 'VB', 'NG2', 'FW', 'Lottery', 'PP') THEN b.transdesc	
								WHEN c.Product IN ('SB', 'Lucky3', 'VS2') THEN ISNULL(b.transdesc, '')
								WHEN c.Product IN ('BF') THEN ISNULL(b.transdesc, '')
								ELSE '' END
				,OddsSpread = CASE
								WHEN c.Product IN ('OneRNG') THEN ISNULL(b.oddsspread, 0)
								WHEN c.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
								ELSE 0 END
				,BetdaqId = -1
				,ExtraInfo = CASE
								WHEN c.Product IN ('PG') THEN ISNULL(b.ExtraInfo, '')
								ELSE '' END	
				,Currency = b.currencyname
			FROM @Tickets AS c
				INNER JOIN dbo.bettrans14 AS b WITH(NOLOCK) ON b.transid = c.transid
				LEFT JOIN dbo.match14 AS m WITH(NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') AND b.matchid = m.matchid
				LEFT JOIN dbo.bettransm14 AS bm WITH(NOLOCK) ON c.Product = 'CB' AND bm.refno = b.refno AND bm.bettype = 18001
				LEFT JOIN dbo.outright14 AS o WITH(NOLOCK) ON c.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH(NOLOCK) ON c.Product IN ('Outright') AND o.leagueID = l.leagueID
				LEFT JOIN dbo.VSOutright14 AS vo WITH(NOLOCK) ON c.Product IN ('VR') AND b.oddsid = vo.Orid
				LEFT JOIN dbo.VSRaceInfo AS vr WITH(NOLOCK) ON c.Product IN ('VR') AND vr.EventID = vo.EventID
				LEFT JOIN dbo.Match3rd14 AS m3 WITH(NOLOCK) ON c.Product IN ('BF') AND b.matchid = m3.Match3rdId	

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
				INNER JOIN dbo.bettransm14 AS bm WITH(NOLOCK) ON c.Product IN ('VR') AND c.refno = bm.refno AND bm.custid = @custid
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
				INNER JOIN dbo.bettransg14 AS bg WITH(NOLOCK) ON c.Product IN ('GD') AND c.transid = bg.refno AND bg.custid = @custid
			WHERE c.Product IN ('GD') --Gold Deluxe
		END -- end: @@rowcount > 0
	END -- end: bettrans14

	SELECT *
	FROM #MemBetTicket
	ORDER BY 1 DESC

	-- OUTPUT ticket detail
	SELECT * 
	FROM @BettransDetail
	ORDER BY RefNo DESC

	DROP TABLE #MemBetTicket
END




GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinLossByDate_Mem] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinLossByDate_Mem] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinLossByDate_Mem] TO [vnteam] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinLossByDate_Mem] TO [vnteam] AS [dbo]
GO
