/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE bodb02
GO
ALTER PROCEDURE [dbo].[Age_BetList_SelDeleted_UserList_MAg]
	@CustId		INT			= NULL,
	@Username	VARCHAR(50) = NULL -- for API
AS

/*
	Created by: []
	DB: DBAGE.bodb02
	Original: BetsSelBetListDeleted_MAg
 
	Revisions:
		- 20071211@Phuc: add username for calling from API
		- 20081106@VinhTrinh: Get more result for Outright and Horseracing
		- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100628@Henry: Remove redundant data
		- 20120628@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
							change DB052 server to DB053 server
		- 20130228@Elodie: Add Virtual HR report
		- 20140303@Elodie: Add Keno sport [Redmine:#12756]
		- 20141103@Dom: Apply sport bettype matrix
		- 20150522@Bobby: Rollback code caused by holding core bet list
		- 20150526@Bobby: Implement bet list core
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150910@Bobby: Enhance performence for SP core. Apply TVP for input parameters
		- 20160105@Kos: Don't support RNG Casino Single Wallet [Redmine: 48958]
		- 20160215@Kos: Don't support AllBet [#Redmine: 50864]
		- 20160401@Kos: Don't support Macau Games [#Redmine: 54643]
		- 20160712@Kos: Change to use inline function for SportBettypeMatrix
		- 20161101@Kos: Don't support Fishing World [#Redmine: 65934]
		- 20180201@Kos: Don't support Racing, RNG Casino (bettype 71, 72), Bingo, P2P, Cockfighting [#Redmine: 86086]
		- 20180418@Kos: Don't support Pragmatic Casino [#Redmine: 92160]
		- 20180710@Kos: Don't support Poker Games [#Redmine: 97565]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @TransStatus	[dbo].[TVP_BetTicketStatus],
		@BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]

	-- Gather Ticket status
	INSERT INTO @TransStatus
	SELECT StatusId
	FROM dbo.All_f_TransStatus(1)
	WHERE StatusId IN (101, 102)

	-- Gather BettypeMatrix
	-- Don't support RNG Casino Single Wallet, AllBet, Macau Games, Fishing World, Pragmatic Casino, Poker Games
	-- Don't support Deposit products (Playtech Casino, AG Casino, Microgaming Live Casino, Macau, Microgaming RNG Casino)
	-- Don't support Racing, RNG Casino (bettype 71, 72), Bingo, P2P, Cockfighting
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BettypeMatrix
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID NOT IN (2, 4, 6, 7, 9, 10, 11, 13, 14, 17, 19, 21, 22, 24, 25, 32, 33)

	EXEC [bodb02].[dbo].[Age_CoreBetList_SMACancelled_SelBetCount]
		@CustId				= @CustId
		, @Username 		= @Username
		, @RoleId			= 3
		, @TransStatus		= @TransStatus
		, @BettypeMatrix	= @BettypeMatrix

	RETURN;
END






GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelDeleted_UserList_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelDeleted_UserList_MAg] TO [bodbDownlineNetView]
GO
