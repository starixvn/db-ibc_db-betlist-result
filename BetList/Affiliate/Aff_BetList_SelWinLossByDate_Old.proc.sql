/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb_archive]
GO
ALTER PROCEDURE [dbo].[Aff_BetList_SelWinLossByDate_Old]
	@CustId		INT,
	@FromDate	SMALLDATETIME,
	@ToDate		SMALLDATETIME,
	@Language	VARCHAR(2)		= 'E',
	@ShowSB		BIT				= 1,
	@ShowCS		BIT				= 0,
	@ShowRB		BIT				= 0,
	@ShowNG		BIT				= 0,
	@ShowLC		BIT				= 0,
	@ShowVS		BIT				= 0,
	@ShowKN		BIT				= 0,
	@ShowAG		BIT				= 0,
	@ShowGD		BIT				= 0,
	@ShowCB		BIT				= 0,
	@ShowCF		BIT				= 0,
	@Error		INT				= 0		OUTPUT,
	@ErrorMsg	NVARCHAR(500)	= ''	OUTPUT,
	@Duration	INT				= 0	OUTPUT
AS

/*
	Created: 20141016@Bobby
	Task: Implement Affilite member betlist
	DB: DBARC.bodb_Archive
	Original: DBARC.bodb_Archive.dbo.[Age_BetList_SelWinLossByDate_Mem_Old]

	Revisions:
		- 20141016@Bobby: Initial affiliate member betlist
		- 20141222@Bobby: Checking status ID for archiving betlist
		- 20150217@Bobby: Apply sport type matrix table
		- 20150415@Bobby: Support for new 60 bettypes betradar
		- 20160308@Bobby: #50200 - Implement LIC core bet list for Affiliate site and offer new products
		- 20160425@Bobby: #56136 - Support Combo Parlay
		- 20160715@Bobby: #60971 - Fixbug - missing TransStatus param
		- 20160714@Kos: Change to use inline function for SportBettypeMatrix
		- 20170519@Kos: Support CashOut [#Redmine: 71963]

	Param's Explanation:
		- @CustID:		Customer/Player ID
		- @FromDate:	Date only
		- @ToDate:		Date only
		- @Language:	translate to which language
		- @MoveBetsDay: Date only that is a move bet day
		- @ShowSB:		Show sportbooks
		- @ShowCS:		Show RnG Casino
		- @ShowRB:		Show Racing,
		- @ShowNG:		Show Number Game
		- @ShowKN:		Show Keno
		- @ShowVS:		Show Virtual Sports
		- @ShowLC:		Show Live Casino
		- @ShowAG:		Show AG Casino
		- @ShowGD:		Show Gold Deluxe
		- @ShowCB:		Colossus Bets
		- @ShowCF:		Cockfighting
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @startRun DATETIME

	SELECT @startRun = GETDATE()

	DECLARE @TransStatus	[dbo].[TVP_BetTicketStatus]
		, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]

	-- Gather Ticket status
	INSERT INTO @TransStatus
	SELECT StatusId
	FROM bodb02.dbo.All_f_TransStatus (1) stt
	WHERE stt.StatusId IN (111, 112, 113)
	
	-- Gather BettypeMatrix
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BettypeMatrix
	SELECT ProductID, BetType, EventType, SubProduct
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 2, 3, 4, 5, 6, 8, 11, 12, 15, 19, 25)

	-- DO filtering bettype by product
	DELETE FROM @BettypeMatrix
	WHERE ProductID		= CASE WHEN @ShowSB	= 0 THEN 1 END
		OR ProductID	= CASE WHEN @ShowRB	= 0 THEN 2 END
		OR ProductID	= CASE WHEN @ShowNG	= 0 THEN 3 END
		OR ProductID	= CASE WHEN @ShowLC	= 0 THEN 4 END
		OR ProductID	= CASE WHEN @ShowVS	= 0 THEN 5 END
		OR ProductID	= CASE WHEN @ShowCS	= 0 THEN 6 END
		OR ProductID	= CASE WHEN @ShowKN	= 0 THEN 8 END
		OR ProductID	= CASE WHEN @ShowAG	= 0 THEN 11 END
		OR ProductID	= CASE WHEN @ShowGD	= 0 THEN 12 END
		OR ProductID	= CASE WHEN @ShowCB	= 0 THEN 15 END
		OR ProductID	= CASE WHEN @ShowCF	= 0 THEN 19 END
		OR ProductID	= CASE WHEN @ShowSB	= 0 THEN 25 END

	-- CALL to core bet list
	EXEC [dbo].[Aff_CoreBetList_MemArc_SelBetTicket]
		@CustId 			= @CustId
		, @FromDate			= @FromDate
		, @ToDate 			= @ToDate
		, @BettypeMatrix	= @BettypeMatrix
		, @TransStatus		= @TransStatus
		/*, @ColumnOutput		= 'Sporttype,
								Username, 
								TransID,
								BetID,
								Bettype,
								hdp1, 
								hdp2, 
								OddsType,
								Odds, 
								modds,
								Stake, 
								actual_stake,
								Betteam,
								Status,
								RefNO,	
								Transdate,
								Winlostdate,
								Winlost,
								awinlost,
								mwinlost,
								swinlost,
								PlayerComm,
								comm,
								acomm,
								scomm,
								APositiontaking,
								MPositiontaking,
								SPositiontaking,
								Adiscount,
								Mdiscount,
								Sdiscount,
								Liveindicator,
								Livehomescore,
								Liveawayscore,
								IP,
								LeagueID,
								MatchID,
								MatchCode,
								Race,
								HomeID,
								AwayID,
								Betstatus,
								isNeutral,
								custid,
								showtime,
								BetCheck,
								comstatus'*/

	SELECT @Duration = DATEDIFF(MILLISECOND, @startRun, GETDATE());

	RETURN;
	
END


GO
GRANT EXECUTE ON [dbo].[Aff_BetList_SelWinLossByDate_Old] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Aff_BetList_SelWinLossByDate_Old] TO [bodbDownlineNet] AS [dbo]
GO
