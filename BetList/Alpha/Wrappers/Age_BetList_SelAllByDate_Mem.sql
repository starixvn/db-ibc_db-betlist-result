USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_BetList_SelAllByDate_Mem]    Script Date: 3/13/2014 9:51:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelAllByDate_Mem]
	@CustId			INT			= NULL
	, @FromDate		DATETIME
	, @ToDate		DATETIME
	, @Language		VARCHAR(2)	= 'E'
	, @username		VARCHAR(50)	= NULL -- for API
	, @ProductIds	VARCHAR(MAX)
AS

/*
	Created:
	Task: Bet List
	DB: DBAGE.bodb02
	Original BetsSelBetListEnglishAgent2
	Revisions:
		- 20080707@Viet: Remove Teamname, Leaguename, Sportname, TypeName
		- 20081106@VinhTrinh: Get more result(Sporttype: Horseracing) for betlist
		- 20090226@Hiep: Get more result for Casino Integration
		- 20090402@nqminh: add real_refno column
		- 20090406@HanhVu: remove real_refno 
						- change refno field instead of transid for mix parlay
						- hardcode refno field for single bet
		- 20090415@HIepVo: Create @BetListSelAllByDateMem temp table, add column BetID to temp table
		- 20090416@Minh: remove indexName
		- 20090421@HiepVo: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@HiepVo: Change formula of commission
		- 20090522@HiepVo: More filter: ShowHR, ShowFI. Add F.O Horse Racing bet type (split Sport Book); Get more data from bettransm for HR
		- 20090710@Phuc: unhide IP for TB currency
		- 20090930@Phuc: Show the refunded tickets' status based on bettrans.status/ get oddstype
		- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100902@Kiwi: Add Number Game & IBCBet Bingo
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110307@Lukas: change @ShowHR to @ShowRB & get more sporttype (152,153)
		- 20110408@Amy: Change function to get Odds value and showed odds type
						Display odds value and odds type for Number Game
		- 20110512@Johnson: change column bettype in temporary table from tinyint to smallint
		- 20110801@Sophia: change the range of number game's bettype from 81 to 120, add new bettype 29 for Combination Mix parlay
		- 20110809@Sophia: Not to use function f_GetChoice to get betteam (bettype <> 14, 16)
		- 20110811@Sophia: Add new columns actual_stake and modds
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120230@Sophia: Add new bettype: Live Casino, add showtime for Table - Shoe - Hand of LiveCasino
		- 20120405@Hurri: Change bettype for P2P
		- 20120409@Sophia: Remove check checktime with CURRENT_TIMETAMP for Casino, P2P, Bingo
		- 20120419@Lukas: Show transid of main ticket for subticket of system parlay
		- 20120502@Johnson: Get session id(betcheck) for bets list P2P
		- 20120525@Johnson: correct sporttype for p2p
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Show hdp1 for Number game
		- 20120705@Sophia: Get sporttype for outright
		- 20120807@Sophia: Add new parametter @showVS for Virtual Sports (sporttype = 180 for representing)
						- Remove Financial product
		- 20120926@Sophia: Get comstatus
		- 20130225@Elodie: Add bet list of Virtual HR
		- 20131003@Lukas: sort tickets by transid
		- 20140306@Patrick:	Add more Keno product
		- 20140310@Patrick:	Exclude keno from Sportbook
		- 20140907@Dom:	[Redmine #22012] remove duplicate VS transaction id in bet list feature
		- 20141103@Dom: Apply sport bettype matrix
		- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217
		- 20150522@Bobby: Add GD product
		- 20150526@Bobby: Implement bet list core
		- 20150706@Bobby: #39097 - Fixing bug for showing Keno's bettype info
		- 20150710@Bobby: #39381 - Fixing bug for showing Casino Draw tickets
		- 20150826@Kos: Add column OddsSpread to support Myanmar Odds
		- 20150828@Kos: Support Colossus Bet
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20151214@Kos: Support Cockfighting [#Redmine: 48850]
		- 20160215@Kos: Support AllBet [#Redmine: 50864]
		- 20160401@Kos: Support Voidbridge [#Redmine: 54643]
		- 20160712@Kos: Change to use inline function for SportBettypeMatrix
		- 20160811@Kos: Support NG2
		- 20161101@Kos: Support Fishing World [#Redmine: 65934]
		- 20170327@Kos: Change input params for Microsite bet list [#Redmine: 66992]
		- 20170703@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @TransStatus	[dbo].[TVP_BetTicketStatus]
		, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]

	-- Gather Ticket status
	INSERT INTO @TransStatus
	SELECT StatusId
	FROM dbo.All_f_TransStatus (1) stt

	-- Gather BettypeMatrix
	-- Get Betradar Virtual Sports in addition to Virtual Sports
	SET @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BettypeMatrix
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest)

	-- CALL to core bet list
	EXEC [bodb02].[dbo].[Age_CoreBetList_MemTransDate_SelBetTicket]
		@CustId				= @CustId
		, @username			= @username
		, @FromDate			= @FromDate
		, @ToDate			= @ToDate
		, @TransStatus		= @TransStatus
		, @BettypeMatrix	= @BettypeMatrix
		, @ColumnOutput		= 'Username 
								,Sporttype
								,Bettype
								,refno
								,TransID
								,BetID
								,MatchCode
								,MatchID
								,Race
								,HomeID
								,AwayID 
								,hdp1 
								,hdp2 
								,Odds 
								,Modds 
								,Status
								,Stake 
								,actual_stake
								,Winlost
								,awinlost
								,mwinlost
								,swinlost
								,PlayerComm
								,comm
								,acomm
								,scomm
								,Transdate
								,Winlostdate
								,Betteam
								,APositiontaking
								,MPositiontaking
								,SPositiontaking
								,Adiscount
								,Mdiscount
								,Sdiscount
								,LeagueID
								,Liveindicator
								,Livehomescore
								,Liveawayscore
								,IP
								,Betstatus
								,isNeutral
								,oddstype
								,showtime
								,BetCheck
								,comstatus
								,transdesc,
								OddsSpread'
	;
END

GO
GRANT  EXECUTE  ON [dbo].[Age_BetList_SelAllByDate_Mem]  TO [bodbDownlineNet]
GO
GRANT  EXECUTE  ON [dbo].[Age_BetList_SelAllByDate_Mem]  TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelAllByDate_Mem] TO [vnteam]
GO
