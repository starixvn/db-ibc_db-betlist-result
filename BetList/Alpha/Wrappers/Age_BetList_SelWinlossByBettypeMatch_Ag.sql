USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossByBettypeMatch_Ag]
	@MatchId			INT
	, @CustId			INT			= NULL
	, @Username			VARCHAR(50)	= NULL
	, @BetType			INT
	, @Language			VARCHAR(2)	= 'E'
	, @LiveIndicator	INT			= 0
AS

/*
	Created: 
	Task: Betlist
	DB: DBAGE.bodb02
	Original:BetsSelBetListMatchWinLoss_Ag
	Revisions:
		- 200712/11@Phuc: For API
		- 20080108: add leaguename,typenamee2,sportname
		- 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
		- 20090326@Phuc: get indexname for FI
		- 20090406@HanhVu: remove refno
		- 20090416@Minh: remove indexName
		- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@HiepVo: Change formula of commission
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TB currency.
		- 20101123@Jacob: Add column betid in select clause
		- 20110408@Amy: Change function to get Odds value and showed odds type
		- 20110809@Sophia: Add a new parametter @liveindicator
		- 20110811@Sophia: Add new columns actual_stake and modds 
		- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
		- 20120112@Sophia:  Add refno, showtime for Table - Shoe - Hand of LiveCasino 
							Add Sub table for Live Casino
		- 20120926@Sophia: Get comstatus
		- 20141016@Sophia: support Sporting solution-grouped bettype 
		- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217
		- 20150331@Cody: Aplly sport bettype matrix [Redmine: #30169]
		- 20150526@Bobby: Implement betlist core
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150910@Bobby: Enhance performence for SP core. Apply TVP for input parameters
		- 20160712@Kos: Change to use inline function for SportBettypeMatrix
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @TransStatus	[dbo].[TVP_BetTicketStatus]
		, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]

	-- Gather Ticket status
	INSERT INTO @TransStatus
	SELECT StatusId
	FROM bodb02.dbo.All_f_TransStatus (1) stt
	WHERE statusid IN (111, 112, 113)
	
	-- Gather BettypeMatrix
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BettypeMatrix
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)

	;WITH CteBettype (bettype)
	AS (
		SELECT bt.bettype
		FROM @BettypeMatrix bt
			LEFT JOIN (SELECT Bettype, GroupTypeId FROM [dbo].[f_GroupBettype]()) AS f ON f.bettype = bt.bettype
		WHERE bt.bettype = @BetType OR f.GroupTypeId = @BetType
	)

	DELETE bt
	FROM @BettypeMatrix AS bt
		LEFT JOIN CteBettype AS ct ON bt.bettype = ct.bettype
	WHERE ct.bettype IS NULL

	EXEC [bodb02].[dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket]
		@CustId				= @CustId
		,@username			= @Username
		, @RoleId			= 2
		, @MatchId			= @MatchId
		, @Liveindicator 	= @LiveIndicator
		, @Language			= @Language
		, @TransStatus		= @TransStatus
		, @BettypeMatrix	= @BettypeMatrix
		, @ColumnOutput		= 'sporttype,
								username,
								bettype,
								leagueID,
								transid,
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
								winlost,
								awinlost,
								mwinlost,
								swinlost,
								playercomm,
								comm,
								acomm,
								scomm,
								transdate,
								winlostdate,
								betteam,
								apositiontaking,
								mpositiontaking,
								spositiontaking,
								Adiscount,
								Mdiscount,
								Sdiscount,
								liveindicator,
								livehomescore,
								liveawayscore,
								matchid,
								IP,
								betstatus,
								IsNeutral,
								OddsType,
								betid,
								showtime,
								refno,
								betcheck,
								comstatus,
								transdesc,
								OddsSpread'
		
	RETURN;
END




GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossByBettypeMatch_Ag] TO vnteam
