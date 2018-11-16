/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossByBettypeMatch_SAg]
	@MatchId			INT
	, @CustId			INT			= NULL
	, @Username			VARCHAR(50)	= NULL
	, @BetType			INT
	, @Language			VARCHAR(2)	= 'E'
	, @LiveIndicator	INT			= 0
AS

/*
	Created: 
	Task : Betlist
	DB: DBAGE.bodb02
	Original:BetsSelBetListMatchWinLoss_SAg
	Revisions:
		- 20071211@Phuc: For API
		- 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
		- 20090326@Phuc: get indexname for FI
		- 20090407@HanhVu: remove refno
		- 20090416@Minh: remove indexName
		- 20090421@Henry: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@HiepVo: Change formula of commission
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TB currency
		- 20101123@Jacob: Add column betid in select clause
		- 20110408@Amy: Change function to get Odds value and showed odds type
		- 20110809@Sophia: Add a new parametter @liveindicator
		- 20110811@Sophia: Add new columns actual_stake and modds
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120112@Sophia: Add refno, showtime for Table - Shoe - Hand of LiveCasino 
							Add Sub table for Live Casino
		- 20120927@Sophia: Get comstatus
		- 20141016@Sophia: support Sporting solution-grouped bettype 
		- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217
		- 20150331@Cody: Aplly sport bettype matrix [Redmine: #30169]
		- 20150522@Bobby: Rollback code caused by holding core bet list
		- 20150526@Bobby: Implement betlist core
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20160712@Kos: Change to use inline function for SportBettypeMatrix
		- 20180201@Kos: Support Sportsbook, Number Game, Lucky 3, Virtual Sports, Betradar Virtual Sports		
					and Bullfighting only [#Redmine: 86086]
		- 20180305@Kos: Include Void/Reject/Refund tickets [#Redmine: 91150]
		- 20181116@Kos: Improve performance [#Redmine: 103577]
*/

BEGIN
	SET NOCOUNT ON;

	EXEC [dbo].[Age_BetList_SelWinlossByBettypeMatch]
		@MatchId		= @MatchId,
		@CustId			= @CustId,
		@Username		= @Username,
		@RoleId			= 4,
		@BetType		= @BetType,
		@LiveIndicator 	= @LiveIndicator
END



GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_SAg] TO vnteam
GO
