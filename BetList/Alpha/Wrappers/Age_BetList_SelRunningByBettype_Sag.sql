/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelRunningByBettype_SAg]
	@CustId		INT,
	@BetType	INT,
	@Language	VARCHAR(2) = 'E'
AS

/*
	Created:
	Task: Betlist
	DB: DBAGE.bodb02
	Original: BetsSelBetList_SAg
	Revisions:
		- 20080104@Vinh: include mix parlay
		- 20080105: Add typenamee2,sportname
		- 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
		- 20090326@Phuc: get indexname for FI
		- 20090406@HanhVu: remove refno
		- 20090416@Minh: remove indexName
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TB currency
		- 20090930@Phuc: get oddstype
		- 20091208@Henry: Add 1 more column: refno for calling Mix Parlay SP
		- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20110408@Amy: Change function to get Odds value and showed odds type
		- 20110516@Johnson: Apply new arrange bettype
		- 20110801@Sophia: Add new bettype = 29 : Combination mix parlay
		- 20110802@Lukas: get 'waiting' tickets for mix parlay - support live-mix parlay
		- 20110809@Sophia: Not to use function f_GetChoice to get betteam ( Bettype <> 14, 16)
		- 20110811@Sophia: Add new columns actual_stake and modds
		- 20110829@Sophia: Add new columns BetID
		- 20110930@Johnson: Get matchid into betlist
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120119@Sophia: Add showtime for Table - Shoe - Hand of LiveCasino
							Add Sub table for Live Casino
		- 20120424@Lukas: Get more column custid
		- 20120705@Sophia: Get sporttype for outright
		- 20120926@Sophia: Get Comstatus
		- 20140425@Dom: Group TB and FGLG
		- 20140611@Dom: Support BetRadar [Redmine: #17148]
		- 20150407@Cody: Apply sport bettype matrix [Redmine: #30169]
		- 20150407@Cody: Support 60 BetRadar bettype (186) [Redmine: 32734]
		- 20150526@Bobby: Implement bet list core
		- 20150826@Kos: Add column OddsSpread to support Myanmar Odds
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20151125@Kos: Support new bet type (410) for Total Bet of Double Chance
		- 20170721@Kos: Use inline function for SportBettypeMatrix and include bet type 427, 431, 433 [Redmine: #53153]
		- 20171012@Kos: Support PH AIO Phase 3 [Redmine: #82399]
		- 20180411@Kos: Enhance performance when getting SportBetTypeMatrix [#Redmine: 93257]
		- 20180621@Kos: Change to use new core [#Redmine: 97249]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]

	-- Gather BettypeMatrix
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BettypeMatrix
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE (@BetType = 6		AND BetType IN (6, 126))
		OR (@BetType = 14	AND BetType IN (14, 127))
		OR (@BetType = 24	AND BetType IN (24, 151, 186, 410, 431))
		OR (@BetType = 26	AND BetType IN (26, 145, 146, 170, 188, 427, 433))
		OR (@BetType = 1	AND BetType IN (1, 301))		-- Support Myanmar Odds
		OR (@BetType = 3	AND BetType IN (3, 302))		-- Support Myanmar Odds
		OR (@BetType = 7	AND BetType IN (7, 303))		-- Support Myanmar Odds
		OR (@BetType = 8	AND BetType IN (8, 304))		-- Support Myanmar Odds
		OR (@BetType = 28	AND BetType IN (28, 453))		-- Support Myanmar Odds
		OR BetType = @BetType

	EXEC [dbo].[Age_CoreBetList_SelRunning]
		@CustId				= @CustId
		, @RoleId			= 4
		, @Language			= @Language
		, @BettypeMatrix	= @BettypeMatrix
		, @ColumnOutput		= 'sporttype,
								username,
								bettype,
								custid,
								transid,
								refno,
								matchid,
								matchcode,
								homeID,
								awayID,
								hdp1,
								hdp2,
								odds,
								modds,
								status,
								stake,
								actual_stake,
								transdate,
								betteam,
								betID,
								livehomescore, 
								liveawayscore,
								liveindicator ,
								tpositiontaking,
								spositiontaking,
								mpositiontaking,
								apositiontaking, 
								adiscount,
								mdiscount,
								sdiscount,
								IP,
								IsNeutral,
								OddsType,
								showtime,
								comstatus,
								transdesc,
								OddsSpread'
END


GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunningByBettype_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunningByBettype_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelRunningByBettype_SAg] TO vnteam
GO
