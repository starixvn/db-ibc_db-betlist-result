/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_BetList_SelDeleted_xtest]    Script Date: 5/13/2015 1:04:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelDeleted]
	@CustId		INT,
	@RoleId		INT			= 1,
	@Language	NVARCHAR(2)	='E'
AS

/*
	Task: 
	DB: DBAGE.bodb02
	Original: BetsSelBetListDeleted

	Revisions:
		- 20060222@[]: remove refno
		- 20071112@Thien: add username for calling from API
		- 20080513@Viet: add IP
		- 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
		- 20090416@Minh: remove indexName
		- 20090523@Hiep: get more result for Horse racing fix odds
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TP currency.
		- 20091003@[MinhNguyen]: get oddstype.
		- 20091024@[MinhNguyen]: get modds, finalodds.
		- 20091208@Henry: get real refno (column refno from bettrans)
		- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20110408@Amy: Change function to get Odds value and showed odds type
						Remove hardcode for b.status
		- 20110811@Sophia: Add betID
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120119@Sophia: Add show time for LiveCasino: Sporttype: 162, bettype: 1101 -> 1199
						- Add Detail for Live Casino
		- 20120704@Jamie: Insert wrong column in temp table for groupmatch and eventdate at Agent Level
		- 20130228@Elodie: Add Virtual HR report
		- 20140303@Elodie: Add Keno sport [Redmine:#12756]
		- 20141103@Dom: Apply sport bettype matrix
		- 20150504@Tom: Get BetCheck Column
		- 20150522@Bobby: Add GD product
		- 20150526@Bobby: Implement bet list core
		- 20150706@Bobby: #39097 - Fixing bug for showing Keno's bettype info
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20160105@Kos: Don't support RNG Casino Single Wallet [Redmine: 48958]
		- 20160215@Kos: Don't support AllBet [#Redmine: 50864]
		- 20160401@Kos: Don't support Voidbridge [#Redmine: 54643]
		- 20160712@Kos: Change to use inline function for SportBettypeMatrix
		- 20161101@Kos: Don't support Fishing World [#Redmine: 65934]
		- 20180201@Kos: Don't support Racing, RNG Casino (bettype 71, 72), Bingo, P2P, Cockfighting [#Redmine: 86086]
		- 20180418@Kos: Don't support Pragmatic Casino [#Redmine: 92160]
		- 20180710@Kos: Don't support Poker Games [#Redmine: 97565]

	Param's Explanation:
		- @CustID: SAgentID
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @EventDate	DATETIME,
		@TransStatus	[dbo].[TVP_BetTicketStatus],
		@BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]

	SET @EventDate = DATEADD(DAY, -3, CURRENT_TIMESTAMP)
	
	-- Gather Ticket status
	INSERT INTO @TransStatus
	SELECT StatusId
	FROM dbo.All_f_TransStatus(1)
	WHERE StatusId IN (101, 102)

	-- Gather BettypeMatrix
	-- Don't support RNG Casino Single Wallet, AllBet, Voidbridge, Fishing World, Pragmatic Casino, Poker Games
	-- Don't support Deposit products (Playtech Casino, AG Casino, Microgaming Live Casino, Macau, Microgaming RNG Casino)
	-- Don't support Racing, RNG Casino (bettype 71, 72), Bingo, P2P, Cockfighting
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BettypeMatrix
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID NOT IN (2, 4, 6, 7, 9, 10, 11, 13, 14, 17, 19, 21, 22, 24, 25, 32, 33)
		AND BetType NOT IN (901, 902, 903, 904)

	EXEC [dbo].[Age_CoreBetList_SMABettype_SelBetTicket]
		@CustId 			= @CustId
		, @RoleId			= @RoleId
		, @EventDate 		= @EventDate
		, @TransStatus		= @TransStatus
		, @BettypeMatrix	= @BettypeMatrix
		, @ColumnOutput		= 'Sporttype,
								Username,
								Custid,
								TransID,
								transdate,
								winlostdate,
								refno,
								HomeID,
								AwayID,
								Betteam,
								Bettype,
								hdp1,
								hdp2,
								Modds,
								oddstype,
								Odds,
								Stake,
								Status,
								Liveindicator,
								Livehomescore,
								Liveawayscore,
								SPositiontaking,
								MPositiontaking,
								APositiontaking,
								Adiscount,
								Mdiscount,
								Sdiscount,
								LeagueID,
								matchid,
								MatchCode,
								Race,
								eventdate,
								IP,
								isNeutral,
								Placing,
								BetID,
								showtime,
								BetCheck,
								transdesc,
								OddsSpread'

	RETURN;
END





GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelDeleted] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelDeleted] TO [bodbDownlineNetView]
GO
