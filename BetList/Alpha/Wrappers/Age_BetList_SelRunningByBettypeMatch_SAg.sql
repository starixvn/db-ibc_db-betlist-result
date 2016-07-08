USE bodb_AGE
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelRunningByBettypeMatch_SAg]
	@MatchID			INT
	, @CustID			INT
	, @Bettype			INT
	, @Language			VARCHAR(2)		= 'E'
	, @liveindicator	INT				= 0
	, @Betteam			NVARCHAR(20)	= NULL
AS
/*
	Created: 
	Task : Betlist
	DB: DBAGE/bodb_AGE
	Original: BetsSelBetListMatchWinLoss_SAg
	Revisions:
		- 20080105: Add typenamee2,sportname 
		- 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
		- 20081030@QuangVinh: Add more result for Horseracing 
		- 20090406@HanhVu: remove refno
		- 20090416@Minh: remove indexName
		- 20090605@HiepVo: remove Horse racing bettype
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TB currency.
		- 20090930@Phuc: get oddstype.
		- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100619@Thien: put index hint Bettrans b with (nolock, index=IX_srecommend) 
		- 20101123@Jacob: Add column betid in select clause
		- 20110408@Amy: Change function to get Odds value and showed odds type
		- 20110415@Viet: temporary remove liveindicator's condition
		- 20110418@Jamie: Check liveindicator for Number Game only 
		- 20110516@Johnson: Apply new arrange bettype
		- 20110810@Sophia: Add new parametter @betteam
		- 20110811@Sophia: Add new columns actual_stake and modds
		- 20110930@Johnson: Get column matchid into betlist
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
		- 20120120@Sophia:  Add refno, showtime for Table - Shoe - Hand of LiveCasino 
							Add Sub table for Live Casino
		- 20120705@Sophia: Get sporttype for outright
		- 20120926@Sophia: Get Comstatus
		- 20130107@Dan: merge code from production	
		- 20130121@Dan: Move sp from DB053/bodb02 to DBAGE/bodb_AGE
		- 20140425@Dom: Group TB and FGLG
		- 20150416@Tom: Integrate new 60 bet types from BetRadar (32734)
		- 20150522@Bobby: Rollback code caused by holding core bet list
		- 20150526@Bobby: Implement betlist core
		- 20150826@Kos: Add column OddsSpread to support Myanmar Odds
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion			
		- 20150910@Bobby: Enhance performence for SP core. Apply TVP for input parameters
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE	 @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]

			
	-- Gather BettypeMatrix
	INSERT INTO @BettypeMatrix
	SELECT DISTINCT productid, bettype, eventtype, subproduct
	FROM bodb02.dbo.SportBettypeMatrix b WITH(NOLOCK)
	WHERE (

			(@bettype		= 6 	AND b.bettype IN(6,159,161,162,126,179,181,182)) 
			OR (@bettype  	= 14 	AND b.bettype IN(14,127)) 
			OR (@bettype	= 2 	AND b.bettype IN(2,157)) 
			OR (@bettype	= 15 	AND b.bettype IN(15,167)) 
			OR (@bettype 	= 1 	AND b.bettype IN(1, 301))		-- Support Myanmar Odds
			OR (@bettype 	= 3 	AND b.bettype IN(3, 302))		-- Support Myanmar Odds
			OR (@bettype 	= 7 	AND b.bettype IN(7, 303))		-- Support Myanmar Odds
			OR (@bettype 	= 8 	AND b.bettype IN(8, 304))		-- Support Myanmar Odds
			OR bettype 		= @bettype 
		)
	
	EXEC [dbo].[Age_CoreBetList_Running_SelBetTicket]
		@CustId 			= @CustId
		, @RoleId			= 4
		, @MatchId 			= @MatchID
		, @Liveindicator 	= @liveindicator
		, @Betteam			= @Betteam
		, @Language 		= @Language
		, @BettypeMatrix	= @BettypeMatrix
		, @ColumnOutput		= 'Sporttype,
								Username,      		
								Bettype,     
								TransID,     
								matchid,
								Matchcode,
								Race, 
								leagueid,
								HomeID,
								AwayID, 
								hdp1,
								hdp2,
								odds,   
								modds,
								status,     
								stake,  
								actual_stake,
								Transdate,    		
								Betteam,
								Liveindicator,
								Livehomescore,
								Liveawayscore,
								APositiontaking,  		
								MPositiontaking,		
								SPositiontaking,
								Adiscount,
								Mdiscount,
								Sdiscount,
								IP,
								IsNeutral,
								oddstype,
								betid,
								showtime,
								refno,
								comstatus,
								transdesc,
								OddsSpread'
		
	RETURN;
END

GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunningByBettypeMatch_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunningByBettypeMatch_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelRunningByBettypeMatch_SAg] TO [vnteam]
