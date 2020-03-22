/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelRunning_Mem]
	@CustId		INT			= NULL,
	@FromDate	DATETIME	= '',
	@ToDate		DATETIME	= '',
	@GetAll		BIT			= 0,
	@Username	VARCHAR(30)	= NULL, -- for API
	@ProductIds	VARCHAR(MAX)
AS

/*
	Created:
	Task: Bet List
	DB: DBAGE.bodb02
	Original DBAGE.bodb_Age.Age_BetList_SelRunningByDate_Mem
	Revisions:
		- 20080707@Viet: Remove Teamname, Leaguename, Sportname, TypeName
		- 20081106@VinhTrinh: Get more result(Sporttype: Horseracing) for betlist
		- 20090227@Hiep: Get more result for Casino Integration
		- 20090406@HanhVu: remove Refno
		- 20090415@HiepVo: Create @BetListSelAllByDateMem temp table, add column BetID to temp table
		- 20090416@Minh: remove indexName
		- 20090417@HiepVo: re-add Refno since Refno is used for Casino
		- 20090506@Simon: add BetType=112 for Casino
		- 20090522@HiepVo: More filter: ShowHR, ShowFI. Add F.O Horse Racing bet type (split Sport Book); Get more data from bettransm for HR
		- 20090710@Phuc: unhide IP for TB currency
		- 20090930@Phuc: get oddstype
		- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100902@Kiwi: Add Number Game & IBCBet Bingo
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110308@Lukas: change @ShowHR -> @ShowRB
		- 20110408@Amy: Change function to get Odds value AND showed odds type
						Show Odds value AND odds type for Number Game
		- 20110516@Johnson: Apply new arrange bettype
		- 20110801@Sophia: change the range of number game's bettype from 81 to 120, add new bettype 29 for Combination Mix parlay
		- 20110809@Sophia: Not to use function f_GetChoice to get betteam (bettype <> 14, 16)
		- 20110811@Sophia: Add new columns actual_stake AND modds 
		- 20110929@Johnson: Get column matchid into betlist
		- 20111118@Lukas: using [creator] column AS sporttype (for racing tickets)
		- 20111122@Sophia: Add Checktime AND SecAcceptFlag to show status waiting or running
						- Change Sporttype of P2P to 253
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120112@Sophia: Add show time Table - Shoe - Hand of Live Casino
		- 20120405@Hurri: Change bettype for P2P
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Show hdp1 for Number game
		- 20120705@Sophia: Get sporttype for outright
		- 20120807@Sophia: Add new parametter @showVS for Virtual Sports (sporttype = 180 for representing)
						. Remove Financial product
		- 20120926@Sophia: Get Comstatus
		- 20130107@Dan: merge code from production
		- 20130121@Dan: Move sp from DB053/bodb02 to DBAGE/bodb_AGE
		- 20130225@Elodie: Add bet list of Virtual HR
		- 20140307@Patrick: Add more Keno product
		- 20140310@Patrick: Exclude keno from Sportbook
		- 20140611@Dom: Support BetRadar [Redmine: #17148]
		- 20140907@Dom: Remove duplicate VS transaction id in bet list feature [Redmine #22012]
		- 20141103@Dom: Apply sport bettype matrix
		- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217
		- 20150522@Bobby: Add GD product
		- 20150706@Bobby: #39097 - Fixing bug for showing Keno's bettype info
		- 20150924@Bobby: Add Metric Gaming product
		- 20150925@Kos: Add Myanmar Odds and Colossus Bet
		- 20151022@Kos: Return [translog].[transid3rd] to support view ticket detail
		- 20151118@Kos: Change length of Username column of temp table to 30
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151217@Kos: Support Cockfighting (#Redmine: 48850)
		- 20151229@Kos: Support Colossus Bet ticket flow change [Redmine: #49967]
		- 20160106@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160125@Kos: Support PH All In One 1.2 [Redmine: #50897]
		- 20160125@Kos: Fix Colossus Bet result issue
		- 20160216@Kos: Support yesterday running ticket for Casino products [Redmine: #52277]
		- 20160216@Kos: Hotfix - Missing Cockfighting [Redmine: #54269]
		- 20160217@Kos: Support AllBet [Redmine: #50864]
		- 20160328@Francis: Change to use inline function instead of table variable to enhance performance
		- 20160401@Kos: Support Macau Games [#Redmine: 54643]
		- 20160411@Kos: Support Combo Parlay [Redmine: #55282]
		- 20160812@Kos: Support NG2
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20161020@Francis: Check tickets existence in bettransRNG/bettransLC before querying to enhance performance [Redmine: #58288]
		- 20161101@Kos: Don't support Bingo and P2P anymore [#Redmine: 53988]
					- Support Fishing World [#Redmine: 65934]
		- 20170301@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170327@Kos: Change input params, return column CustId for Microsite bet list [#Redmine: 66992]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170705@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170718@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20170829@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171027@Kos: Support Bullfighting [#Redmine: 84961]
					- Don't support Live Casino anymore
		- 20180131@Kos: Don't support Racing, Cockfighting, RNG Casino (bettype 71, 72) anymore [#Redmine: 86086]
		- 20180326@Kos: Hotfix - Remove duplicate Virtual Sports [#Redmine: 92748]
		- 20180330@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180418@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180617@Kos: Change to use bodb02.bettrans instead of bodb_Age.bettrans_running [#Redmine: 97037]
		- 20180625@Kos: Check running tickets exist to enhance performance [#Redmine: 97249]
					- Comment Colossus Bets block of code due to inactive
		- 20180625@Kos: Use INDEX HINT and force nested loop for translog [#Redmine: 97249]
		- 20180703@Kos: Use new index for bettransRnG and bettransLC [#Redmine: 97249]
		- 20180705@Viet: Rewrite SP
		- 20180731@Patrick: Index revolution [#Redmine: #98757]
		- 20180803@Kos: Support Poker Games [#Redmine: 97565]
		- 20181002@Kos: Support 2 new status Result Pending and Under Settlement [#Redmine: 101949]
					- Remove param @Language
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190506@Kos: Show match KO time for single ticket [Redmine: #112092]
		- 20190611@Kos: Support Card Club [Redmine: #107645]
					- Don't support Poker Games anymore
		- 20190722@Kos: Support new status Pending [#Redmine: 113142]
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20191028@Kos: Show Running status for Marked tickets [Redmine: 122391]
		- 20191029@Kos: Support Spadegaming [Redmine: #122140]
		- 20191218@Kos: Support Virtual Games [Redmine: #124759]
		- 20200302@Kos: Support SA Gaming [Redmine: #128048]
		- 20200324@Kos: Support Sexy Gaming [Redmine: #130680]
		- 20200331@Kos: Support Saba.club [Redmine: #130769]
*/

BEGIN
	SET NOCOUNT ON;

	IF @CustId IS NULL
	BEGIN
		SELECT @CustId = custid
		FROM dbo.Customer WITH (NOLOCK)
		WHERE username = @Username
	END

	DECLARE @BetListSelRunningByDateMem TABLE (
		SportType			SMALLINT,
		BetType				SMALLINT,
		LeagueId			INT,
		RefNo				BIGINT,
		TransId				BIGINT,
		BetId				BIGINT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(20),
		EventDate			DATETIME,
		MatchId				INT,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		MOdds				MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		WinLostDate			DATETIME,
		BetTeam				NVARCHAR(20),
		APositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		SPositionTaking		SMALLMONEY,
		ADiscount			SMALLMONEY,
		MDiscount			SMALLMONEY,
		SDiscount			SMALLMONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					NVARCHAR(15),
		IsNeutral			BIT,
		OddsType			TINYINT,
		ShowTime			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		ExtraInfo			VARCHAR(1000),
		SecAcceptFlag		BIT,
		OddsId				INT,
		CheckTime			DATETIME,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		Custom3				NVARCHAR(50),
		Gameid3rd			NVARCHAR(50),
		Tranid3rd			NVARCHAR(64),
		ProductID			INT,
		EventType			INT,
		SubProduct			VARCHAR(500),
		TableID				TINYINT
	)

	DECLARE @BetListDetail TABLE(
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(20),
		TransDesc		VARCHAR (1000)
	)

	-- CONSTANT VALUE: 1:bettrans; 2:translog; 4:bettransRnG; 8:bettransLC
	DECLARE @hasData TINYINT = 0

	-- bettrans
	INSERT INTO @BetListSelRunningByDateMem (
		TransId
		,TransDate
		,WinLostDate --bettrans.transdate
		,MatchId
		,BetType
		,Status
		,Actual_Stake
		,MDiscount -- bettrans.adiscount
		,APositionTaking
		,BetCheck
		,BetId
		,BetTeam
		,CheckTime
		,ComStatus
		,ADiscount --bettrans.discount
		,Hdp1
		,Hdp2
		,Ip
		,LiveAwayScore
		,LiveHomeScore
		,LiveIndicator
		,MOdds
		,MPositionTaking
		,Odds
		,OddsId
		,OddsSpread
		,OddsType
		,RefNo
		,SDiscount
		,SecAcceptFlag
		,SPositionTaking
		,Stake
		,TransDesc
		,ExtraInfo
		,TableID
	)
	SELECT TransID = transid
		,TransDate = transdate
		,WinLostDate = transdate -- winlostdate
		,MatchID = matchid
		,BetType = bettype
		,[Status] = [status]
		,Actual_Stake = actual_stake
		,MDiscount = adiscount --mdiscount
		,APositionTaking = apositiontaking
		,BetCheck = ISNULL(betcheck, '') --betcheck
		,BetId = ISNULL(betid, 0) --betid
		,BetTeam = betteam
		,CheckTime = checktime
		,ComStatus = comstatus
		,ADiscount = discount --adiscount
		,Hdp1 = hdp1
		,Hdp2 = hdp2
		,Ip = ip
		,LiveAwayScore = liveawayscore
		,LiveHomeScore = livehomescore
		,LiveIndicator = liveindicator
		,MOdds = modds
		,MPositionTaking = mpositiontaking
		,Odds = odds
		,OddsId = oddsid
		,OddsSpread = ISNULL(oddsspread, 0)
		,OddsType = oddstype
		,RefNo = refno
		,SDiscount = sdiscount
		,SecAcceptFlag = SecAcceptFlag
		,SPositionTaking = spositiontaking
		,Stake = stake
		,TransDesc = ISNULL(transdesc, '')
		,ExtraInfo = ISNULL(ExtraInfo, '')
		,TableID = 1 --bettrans
	FROM dbo.bettrans WITH (NOLOCK, INDEX = IX_betrunning_custid)
	WHERE custid = @CustId
		AND statusID IN (0,1)
		AND transdate >= CASE @GetAll WHEN 1 THEN transdate ELSE @FromDate END
		AND transdate <= CASE @GetAll WHEN 1 THEN transdate ELSE @ToDate END

	SET @hasData += CASE @@ROWCOUNT WHEN 0 THEN 0 ELSE 1 END	-- bettrans

	-- translog
	INSERT INTO @BetListSelRunningByDateMem (
		TransId
		,TransDate
		,WinLostDate --bettrans.transdate
		,MatchId
		,SportType
		,BetType
		,Status
		,Actual_Stake
		,MDiscount -- bettrans.adiscount
		,APositionTaking
		,BetCheck
		,BetId
		,BetTeam
		,CheckTime
		,ComStatus
		,ADiscount --bettrans.discount
		,Hdp1
		,Hdp2
		,Ip
		,LiveAwayScore
		,LiveHomeScore
		,LiveIndicator
		,MOdds
		,MPositionTaking
		,Odds
		,OddsId
		,OddsSpread
		,OddsType
		,RefNo
		,SDiscount
		,SecAcceptFlag
		,SPositionTaking
		,Stake
		,TransDesc
		,Custom1
		,Custom2
		,Custom3
		,Gameid3rd
		,Tranid3rd
		,TableID
	)
	SELECT TransId = translogid
		,TransDate = transdate
		,WinLostDate = transdate
		,MatchId = eventID
		,SportType = productID
		,BetType = gameID
		,Status = status
		,Actual_Stake = actual_stake
		,MDiscount = adiscount
		,APositionTaking = apositiontaking
		,BetCheck = ''
		,BetId = 0
		,BetTeam = ''
		,CheckTime = NULL
		,ComStatus = 0
		,ADiscount = discount
		,Hdp1 = 0
		,Hdp2 = 0
		,Ip = ip
		,LiveAwayScore = 0
		,LiveHomeScore = 0
		,LiveIndicator = LiveIndicator
		,MOdds = 0
		,MPositionTaking = mpositiontaking
		,Odds = odds
		,OddsId = NULL
		,OddsSpread = 0
		,OddsType = 0
		,RefNo = translogid
		,SDiscount = sdiscount
		,SecAcceptFlag = NULL
		,SPositionTaking = spositiontaking
		,Stake = stake
		,TransDesc = transdesc
		,Custom1 = Custom1
		,Custom2 = Custom2
		,Custom3 = Custom3
		,Gameid3rd = Gameid3rd
		,Tranid3rd = Tranid3rd
		,TableID = 2 -- translog
	FROM dbo.translog WITH (NOLOCK, INDEX = IX_betrunning_custid)
	WHERE custid = @CustId
		AND statusID IN (0, 1)
		AND transdate >= CASE @GetAll WHEN 1 THEN transdate ELSE @FromDate END
		AND transdate <= CASE @GetAll WHEN 1 THEN transdate ELSE @ToDate END

	SET @hasData += CASE @@ROWCOUNT WHEN 0 THEN 0 ELSE 2 END	-- translog
	
	-- bettransRnG
	MERGE INTO @BetListSelRunningByDateMem AS d
	USING (
		SELECT TransID = refno
			,Bettype = gameid
			,Stake = SUM(stake)
			,Actual_Stake = SUM(actual_stake)
			,APositiontaking = AVG(apositiontaking)
			,MPositiontaking = AVG(mpositiontaking)
			,SPositiontaking = AVG(spositiontaking)
			,ADiscount = AVG(discount)
			,MDiscount = AVG(adiscount)
			,SDiscount = AVG(sdiscount)
			,TableID = 4 --bettransRnG
		FROM dbo.bettransRnG WITH (NOLOCK)
		WHERE custid = @custid
			AND statusID IN (0, 1)
			AND gameid IN (
					SELECT DISTINCT BetType FROM dbo.SportBettypeMatrix WITH (NOLOCK)
					WHERE ProductID IN (6, 22, 24, 32, 34, 36, 42)
				)
		GROUP BY RefNo, gameID
	) AS s ON s.TransID = d.TransId
	WHEN MATCHED THEN
		UPDATE
		SET Stake = s.Stake
			,Actual_Stake = s.Actual_Stake
			,APositionTaking = s.APositionTaking
			,MPositionTaking = s.MPositionTaking
			,SPositionTaking = s.SPositionTaking
			,ADiscount = s.ADiscount
			,MDiscount = s.MDiscount
			,SDiscount = s.SDiscount
			,TableID = s.TableID
	WHEN NOT MATCHED THEN
		INSERT (TransID
			,bettype
			,Stake
			,Actual_Stake
			,APositionTaking
			,MPositionTaking
			,SPositionTaking
			,ADiscount
			,MDiscount
			,SDiscount
			,TableID
		)
		VALUES (s.TransID
			,s.bettype
			,s.Stake
			,s.Actual_Stake
			,s.APositionTaking
			,s.MPositionTaking
			,s.SPositionTaking
			,s.ADiscount
			,s.MDiscount
			,s.SDiscount
			,s.TableID
		);

	SET @hasData += CASE @@ROWCOUNT WHEN 0 THEN 0 ELSE 4 END --bettransRnG	

	-- bettransLC
	MERGE INTO @BetListSelRunningByDateMem AS d
	USING (
		SELECT TransID = refno
			,Bettype = gameid
			,Stake = SUM(stake)
			,Actual_Stake = SUM(actual_stake)
			,APositiontaking = AVG(apositiontaking)
			,MPositiontaking = AVG(mpositiontaking)
			,SPositiontaking = AVG(spositiontaking)
			,ADiscount = AVG(discount)
			,MDiscount = AVG(adiscount)
			,SDiscount = AVG(sdiscount)
			,TableID = 8 --bettransLC
		FROM dbo.bettransLC WITH (NOLOCK)
		WHERE custid = @CustId
			AND statusid IN (0, 1)
			AND gameID IN (
					SELECT DISTINCT BetType FROM dbo.SportBettypeMatrix WITH (NOLOCK)
					WHERE ProductID IN (21, 39, 45)
				)
		GROUP BY RefNo, gameID
	) AS s ON s.TransID = d.TransID
	WHEN MATCHED THEN
		UPDATE
		SET Stake = s.Stake
			,Actual_Stake = s.Actual_Stake
			,APositionTaking = s.APositionTaking
			,MPositionTaking = s.MPositionTaking
			,SPositionTaking = s.SPositionTaking
			,ADiscount = s.ADiscount
			,MDiscount = s.MDiscount
			,SDiscount = s.SDiscount
			,TableID = s.TableID
	WHEN NOT MATCHED THEN
		INSERT (TransID
			,bettype
			,Stake
			,Actual_Stake
			,APositionTaking
			,MPositionTaking
			,SPositionTaking
			,ADiscount
			,MDiscount
			,SDiscount
			,TableID
		)
		VALUES (s.TransID
			,s.bettype
			,s.Stake
			,s.Actual_Stake
			,s.APositionTaking
			,s.MPositionTaking
			,s.SPositionTaking
			,s.ADiscount
			,s.MDiscount
			,s.SDiscount
			,s.TableID
		);

	SET @hasData += CASE @@ROWCOUNT WHEN 0 THEN 0 ELSE 8 END	-- bettransLC
	
	-- Get currency name
	DECLARE @CurrencyName NVARCHAR(50)

	IF @hasData > 0		-- got data
	BEGIN
		-- Check SP Version
		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)
		
		-- Get Betradar Virtual Sports in addition to Virtual Sports
		SET @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)

		-- get sport/bettype info
		UPDATE b
		SET ProductID = s.ProductID,
			EventType = s.EventType,
			SubProduct = s.SubProduct
		FROM @BetListSelRunningByDateMem b
			INNER JOIN dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) s ON b.bettype = s.bettype

		DELETE @BetListSelRunningByDateMem
		WHERE ProductID IS NULL
			OR (ProductID IN (21, 39, 6, 22, 24, 32, 34, 36, 42, 45) AND TableID = 1)

		IF (@hasData & 1 = 1) --got bettrans' data
		BEGIN
			-- Sportsbook
			UPDATE b
			SET SportType = m.sporttype
				,LeagueId = m.leagueid
				,MatchCode = m.matchcode
				,Race = ''
				,EventDate =  m.GlobalShowTime
				,HomeId = m.homeid
				,AwayId = m.awayid
				,[Status] = CASE
								WHEN b.[Status] = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								ELSE b.[Status]
							END
				,SettlementStatus = ISNULL(m.SettlementStatus, 0)
				,ComStatus = CASE WHEN b.ComStatus = '1' THEN '1' ELSE '0' END
				,IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT, 0))
				,ShowTime = ''
				,ExtraInfo = ISNULL(b.ExtraInfo, '')
			FROM @BetListSelRunningByDateMem AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.TableID = 1 -- bettrans
				AND b.ProductID = 1
				AND b.EventType = 1
				AND b.SubProduct NOT IN ('MG-SuperLive')	-- --exclude running tickets of MetricGaming

			-- Outright
			UPDATE b
			SET SportType = l.sporttype
				,LeagueId = m.leagueID
				,MatchCode = m.matchcode
				,Race = m.GroupMatch
				,EventDate = ''
				,MatchId = 0
				,HomeId = m.teamID
				,AwayId  = 0
				,SettlementStatus = 0
				,ComStatus = CASE WHEN b.ComStatus = '1' THEN '1' ELSE '0' END
				,Hdp1 = 0
				,Hdp2 = 0
				,Betteam = ''
				,LiveIndicator = 0
				,LiveHomeScore = 0
				,LiveAwayScore = 0
				,IsNeutral = 0
				,OddsType = 0
				,ShowTime = ''
				,BetCheck = ''
				,TransDesc = ''
				,OddsSpread = 0
				,ExtraInfo = ''
			FROM @BetListSelRunningByDateMem AS b
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE b.TableID = 1 -- bettrans
				AND b.bettype = 10

			-- Mix Parlay, System Parlay
			UPDATE b
			SET SportType = 0
				,LeagueId = 0
				,MatchCode = ''
				,Race = ''
				,EventDate = ''
				,MatchId = 0
				,HomeId = 0
				,AwayId  = 0
				,Status = CASE
							WHEN b.status = 'running' THEN
								CASE
									WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
												WHERE bm.custid = @CustId
													AND bm.refno = b.refno
													AND (bm.status = 'waiting'
														OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
										THEN 'Waiting'
									ELSE b.status
								END
							ELSE b.status
						END
				,SettlementStatus = 0
				,ComStatus = CASE WHEN b.ComStatus = '1' THEN '1' ELSE '0' END
				,LiveIndicator = 0
				,LiveHomeScore = 0
				,LiveAwayScore = 0
				,IsNeutral = 0
				,OddsType = 0
				,ShowTime = ''
				,TransDesc = ''
				,OddsSpread = 0
				,ExtraInfo = ''
			FROM @BetListSelRunningByDateMem AS b
			WHERE b.bettype IN (9, 29)
				AND b.matchid IN (9, 29)

			-- Number Game, Virtual Sports, Betradar Virtual Sports (EventType = 1)
			UPDATE b
			SET SportType = m.sporttype
				,LeagueId = m.leagueid
				,MatchCode = m.matchcode
				,Race = ''
				,EventDate = m.eventdate
				,MatchId = CASE WHEN b.ProductID IN (5, 27) THEN m.matchid ELSE 0 END
				,HomeId = CASE WHEN b.ProductID IN (5, 27) THEN m.homeid ELSE 0 END
				,AwayId = CASE WHEN b.ProductID IN (5, 27) THEN m.awayid ELSE 0 END
				,SettlementStatus = 0
				,ComStatus = CASE WHEN b.ComStatus = '1' THEN '1' ELSE '0' END
				,Hdp2 = CASE WHEN b.ProductID IN (5, 27) THEN b.hdp2 ELSE 0 END
				,[Status] = CASE
								WHEN b.[Status] = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								ELSE b.[Status]
							END
				,OddsType = CASE WHEN b.ProductID IN (3, 5, 27) THEN b.OddsType ELSE 0 END
				,IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT, 0))
				,ShowTime = CASE
								WHEN b.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
								ELSE ''
							END
				,BetCheck = ''
				,TransDesc = CASE WHEN b.ProductID IN (27) THEN ISNULL(b.TransDesc, '') ELSE '' END
				,OddsSpread = 0
				,ExtraInfo = ''
			FROM @BetListSelRunningByDateMem AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.TableID = 1 -- bettrans
				AND b.ProductID IN (3, 5, 27)
				AND b.EventType = 1

			-- Virtual Sports (EventType = 3)
			UPDATE b
			SET SportType = r.SportType
				,LeagueId = r.LeagueID
				,MatchCode = o.RacerNum
				,Race = b.oddsid
				,EventDate = ''
				,HomeId = o.RacerID
				,AwayId = 0
				,BetTeam = ''
				,SettlementStatus = 0
				,ComStatus = CASE WHEN b.ComStatus = '1' THEN '1' ELSE '0' END
				,OddsType = 0
				,ShowTime = r.EventTime
				,BetCheck = ''
				,TransDesc = ''
				,OddsSpread = 0
				,ExtraInfo = ''
			FROM @BetListSelRunningByDateMem AS b
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
			WHERE b.TableID = 1 -- bettrans
				AND b.ProductID = 5
				AND b.EventType = 3

			-- Betradar Virtual Sports (EventType = 0) -- Mix Parlay
			UPDATE b
			SET SportType = 0
				,LeagueId = 0
				,MatchCode = ''
				,Race = ''
				,EventDate = ''
				,MatchID = 0
				,HomeId = 0
				,AwayId = 0
				,Status = CASE
							WHEN b.status = 'running' THEN
								CASE
									WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
												WHERE bm.custid = @CustId
													AND bm.refno = b.refno
													AND (bm.status = 'waiting'
														OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
										THEN 'Waiting'
									ELSE b.status
								END
							ELSE b.status
						END
				,SettlementStatus = 0
				,ComStatus = CASE WHEN b.ComStatus = '1' THEN '1' ELSE '0' END
				,LiveIndicator = 0
				,LiveHomeScore = 0
				,LiveAwayScore = 0
				,IsNeutral = 0
				,OddsType = 0
				,ShowTime = ''
				,TransDesc = ''
				,OddsSpread = 0
				,ExtraInfo = ''
			FROM @BetListSelRunningByDateMem AS b
			WHERE b.TableID = 1 -- bettrans
				AND b.matchid = 2799

			-- NG2 bettrans
			UPDATE b
			SET Sporttype = CASE
								WHEN b.ProductId = 23 AND b.BetType BETWEEN 2501 AND 2539 THEN 213
								WHEN b.ProductId = 23 AND b.BetType BETWEEN 2541 AND 2579 THEN 214
								WHEN b.ProductId = 23 AND b.BetType BETWEEN 2581 AND 2619 THEN 215
								WHEN b.ProductId = 23 AND b.BetType BETWEEN 2621 AND 2659 THEN 216
								WHEN b.ProductId = 23 AND b.BetType BETWEEN 2681 AND 2699 THEN 218
								ELSE 0
							END
				,LeagueID = 0
				,MatchCode = ''
				,Race = ''
				,EventDate = ''
				,MatchID = 0
				,HomeId = 0
				,AwayID = 0
				,MOdds = 0
				,BetTeam = ''
				,LiveIndicator = 0
				,LiveAwayScore = 0
				,IsNeutral = 0
				,OddsType = 0
				,ShowTime = ''
				,OddsSpread = 0
				,SettlementStatus = 0
				,ComStatus = ''
				,BetCheck = ''
				,ExtraInfo = ''
			FROM @BetListSelRunningByDateMem AS b
			WHERE b.TableID = 1 -- bettrans
				AND b.ProductID = 23
		END -- got bettrans' data

		IF (@hasData & 2 = 2) -- got translog's data
		BEGIN
			-- Metric Gaming
			UPDATE b
			SET SportType = m.sporttype
				,LeagueID = m.leagueid
				,MatchCode = ISNULL(m.MatchCode,'')
				,Race = ''
				,EventDate = m.GlobalShowTime
				,HomeID = m.homeID
				,AwayID = m.awayID
				,LiveIndicator = 0
				,IsNeutral = ISNULL(m.IsNeutral, 0)
				,SettlementStatus = 0
				,OddsType = CASE WHEN b.SubProduct IN ('MG-SuperLive') THEN CONVERT(TINYINT, ISNULL(b.custom1, 0)) ELSE 0 END
				,ShowTime = ISNULL(m.showtime,'')
				,ExtraInfo = ''
			FROM @BetListSelRunningByDateMem AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.TableID = 2 -- translog
				AND b.SubProduct IN ('MG-SuperLive')

			-- Keno, Gold Deluxe, Lottery, Virtual Games (translog)
			UPDATE b
			SET SportType = CASE
								WHEN b.ProductID = 8 THEN 202
								WHEN b.ProductID = 12 THEN 255
								WHEN b.ProductID = 28 THEN 220
								WHEN b.ProductID = 38 THEN b.SportType
								ELSE 0
							END
				,LeagueID = 0
				,MatchCode = ''
				,Race = ''
				,EventDate = ''
				,MatchID = CASE WHEN b.ProductID = 12 THEN 255	ELSE 0 END
				,HomeID = 0
				,AwayID = 0
				,LiveIndicator = 0
				,IsNeutral = 0
				,SettlementStatus = 0
				,ShowTime = ''
				,BetCheck = CASE
								WHEN b.ProductID IN (12, 38) THEN b.Gameid3rd
								WHEN b.ProductId = 8 THEN ISNULL(b.custom2, '')
								ELSE '' 
							END
				,TransDesc = CASE WHEN b.ProductID IN (8, 28, 38) THEN b.transdesc ELSE '' END
				,OddsSpread = 0
				,ExtraInfo = ''
			FROM @BetListSelRunningByDateMem AS b
			WHERE b.TableID = 2 -- translog
				AND b.ProductID IN (8, 12, 28, 38)
		END -- got translog's data

		-- Allbet, RNG Casino Single Wallet, Macau Games, Fishing World, Pragmatic Casino, Card Club, Spadegaming, SA Gaming, Sexy Gaming, Saba.club
		IF EXISTS ( SELECT 1 FROM @BetListSelRunningByDateMem WHERE ProductId IN (21, 6, 22, 24, 32, 34, 36, 39, 42, 45))
		BEGIN
			UPDATE d
			SET TransDate = s.transdate
				,WinLostDate = s.winlostdate -- winlostdate
				,Sporttype = CASE
									WHEN d.ProductID IN (6, 34, 36, 39, 42, 45) THEN s.matchid
									WHEN d.ProductID = 21 THEN 211
									WHEN d.ProductID = 22 THEN 212
									WHEN d.ProductID = 24 THEN 219
									WHEN d.ProductID = 32 THEN 248
									ELSE 0
								END
				,CheckTime = s.checktime
				,Ip = s.ip
				,OddsId = s.oddsid
				,RefNo = s.refno
				,SecAcceptFlag = s.SecAcceptFlag
				,TransDesc = CASE
								WHEN d.ProductID IN (21, 39, 45) THEN ''
								ELSE ISNULL(s.TransDesc, '') --transdesc
							END
				,LeagueID = 0
				,BetID = 0
				,MatchCode = ''
				,Race = ''
				,EventDate = ''
				,MatchID = 0
				,HomeID = 0
				,AwayID = 0
				,Hdp1 = 0
				,Hdp2 = 0
				,Odds = 0
				,MOdds = 0
				,Status = 'Running'
				,SettlementStatus = 0
				,Betteam = ''
				,LiveIndicator = 0
				,LiveHomeScore = 0
				,LiveAwayScore = 0
				,IsNeutral = 0
				,OddsType = 0
				,ShowTime = ''
				,ComStatus = 0
				,BetCheck = ''
				,OddsSpread = 0
				,ExtraInfo = ''
			FROM @BetListSelRunningByDateMem AS d
				INNER JOIN dbo.bettrans AS s WITH (NOLOCK) on d.transid = s.transid
			WHERE d.ProductID IN (21, 6, 22, 24, 32, 34, 36, 42, 45)
				--AND s.statusID > 1 -- settled only

			-- DELETE before yesterday one or not IN From - To range
			DELETE @BetListSelRunningByDateMem
			WHERE ProductID IN (21, 6, 22, 24, 32, 34, 36, 39, 42, 45)
				AND (WinLostDate < DATEADD(dd, DATEDIFF(dd, 0, CURRENT_TIMESTAMP) - 1, 0) --yesterday
					OR TransDate < CASE @GetAll WHEN 1 THEN TransDate ELSE @FromDate END
					OR TransDate > CASE @GetAll WHEN 1 THEN transdate ELSE @ToDate END)
		END

		SELECT
			@Username = c.username,
			@CurrencyName = ex.currency
		FROM dbo.custinfo AS c WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON c.currency = ex.exchangeid
		WHERE c.custid = @CustId

		-- Get sub tickets
		-- Virtual Sports (bettype 1233)
		IF EXISTS (SELECT 1 FROM @BetListSelRunningByDateMem WHERE ProductId = 5 AND EventType = 3)
		BEGIN
			INSERT INTO @BetListDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.mpositiontaking,
				bm.spositiontaking,
				bm.bettype,
				'' AS betteam,
				'' AS transdesc
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @BetListSelRunningByDateMem AS b ON bm.refno = b.refno
			WHERE bm.custid = @CustId
				AND b.ProductID = 5
				AND b.EventType = 3
				AND bm.bettype IN (	SELECT DISTINCT BetType FROM dbo.SportBettypeMatrix WITH (NOLOCK)
									WHERE ProductID = 5 AND EventType = 3)
		END

		-- Gold Deluxe
		IF EXISTS (SELECT 1 FROM @BetListSelRunningByDateMem WHERE ProductId = 12)
		BEGIN
			INSERT INTO @BetListDetail
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
			FROM dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN @BetListSelRunningByDateMem AS b ON bg.refno = b.transid
			WHERE bg.custid = @CustId
				AND b.ProductID = 12
				AND bg.bettype IN (	SELECT DISTINCT BetType FROM dbo.SportBettypeMatrix WITH (NOLOCK)
									WHERE ProductID = 12)
		END
	END -- got data

	SELECT
		SportType
		,BetType
		,LeagueId
		,RefNo
		,TransId
		,BetId
		,MatchCode
		,Race
		,EventDate
		,MatchId
		,HomeId
		,AwayId
		,Hdp1
		,Hdp2
		,Odds
		,MOdds
		,Status
		,SettlementStatus
		,Stake
		,Actual_Stake
		,TransDate
		,WinLostDate
		,BetTeam
		,APositionTaking
		,MPositionTaking
		,SPositionTaking
		,ADiscount
		,MDiscount
		,SDiscount
		,LiveIndicator
		,LiveHomeScore
		,LiveAwayScore
		,Ip
		,IsNeutral
		,OddsType
		,ShowTime
		,ComStatus
		,BetCheck
		,TransDesc
		,OddsSpread
		,ExtraInfo
		,@CustId AS CustId
		,@Username AS Username
		,@CurrencyName AS Currency
	FROM @BetListSelRunningByDateMem
	ORDER BY TransId DESC

	SELECT * FROM @BetListDetail
	ORDER BY RefNo ASC
END
GO




GRANT EXECUTE ON [dbo].[Age_BetList_SelRunning_Mem] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunning_Mem] TO [bodbDownlineNetView] AS [dbo]
GO
