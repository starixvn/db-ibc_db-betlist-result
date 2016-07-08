USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelRunningByBettypeMatch_Ag]
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
	DB: DBAGE.bodb02
	Original: BetsSelBetListMatchWinLoss_Ag
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
		- 20101123@Jacob: Add column betid in select clause
		- 20110408@Amy: Change function to get Odds value and showed odds type
		- 20110415@Viet: temporary remove liveindicator's condition
		- 20110418@Jamie: Check liveindicator for Number Game only 
		- 20110516@Johnson: Apply new arrange bettype
		- 20110810@Sophia: add new parametter @Betteam
		- 20110811@Sophia: Add new columns actual_stake and modds
		- 20110930@Johnson: Get column matchid into betlist
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
		- 20120120@Sophia:  Add refno, showtime for Table - Shoe - Hand of LiveCasino 
							Add Sub table for Live Casino
		- 20120705@Sophia: Get sporttype for outright
		- 20120926@Sophia: Get Comstatus
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
	
	DECLARE	 @TransStatus 	[dbo].[TVP_BetTicketStatus]
		, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]
	
	-- Gather Ticket status
	INSERT INTO @TransStatus

	SELECT StatusId
	FROM bodb02.dbo.All_f_TransStatus (1) stt
	WHERE stt.statusId IN (0, 1)	
	
	-- Gather BettypeMatrix
	INSERT INTO @BettypeMatrix

	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 5
	
	;WITH CteBettype (bettype)
	AS (
		SELECT bt.bettype
		FROM @BettypeMatrix bt
		WHERE (bt.EventType = 1)						-- macth event
			OR (bt.ProductId = 1 AND bt.EventType = 2)	-- outright
	)
	DELETE bt
	FROM @BettypeMatrix bt
		LEFT JOIN CteBettype ct 
		ON bt.bettype = ct.bettype
	WHERE ct.bettype IS NULL
		OR (@bettype NOT IN (6, 14, 2, 15, 1, 3, 7, 8) AND bt.bettype  NOT IN (@bettype))
		OR (@bettype = 6 	AND bt.bettype NOT IN(6,159,161,162,126,179,181,182) )
		OR (@bettype = 14 	AND bt.bettype NOT IN(14,127) )
		OR (@bettype = 2 	AND bt.bettype NOT IN(2,157)) 
		OR (@bettype = 15 	AND bt.bettype NOT IN(15,167))
		OR (@bettype = 1 	AND bt.bettype NOT IN(1, 301))		-- Support Myanmar Odds
		OR (@bettype = 3 	AND bt.bettype NOT IN(3, 302))		-- Support Myanmar Odds
		OR (@bettype = 7 	AND bt.bettype NOT IN(7, 303))		-- Support Myanmar Odds
		OR (@bettype = 8 	AND bt.bettype NOT IN(8, 304))		-- Support Myanmar Odds
		/*
		(@bettype=6 AND b.bettype IN(6,159,161,162,126,179,181,182)) 
			OR (@bettype=14 and b.bettype IN(14,127)) 
			OR (@bettype=2 and b.bettype IN(2,157)) 
			OR (@bettype=15 and b.bettype IN(15,167)) 
			OR bettype = @bettype
		*/
	EXEC [bodb02].[dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket]
		@CustId 			= @CustId
		, @RoleId			= 2
		, @MatchId 			= @MatchID
		, @Liveindicator 	= @liveindicator
		, @Betteam			= @Betteam
		, @Language 		= @Language
		, @TransStatus		= @TransStatus
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
								Adiscount,
								IP,
								isNeutral,
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
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunningByBettypeMatch_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunningByBettypeMatch_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelRunningByBettypeMatch_Ag] TO [vnteam]