/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_RNG_Detail]    Script Date: 10/12/2015 11:00:26 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Aff_BetList_RNG_Detail]
	@RefNo		BIGINT,
	@CustId		INT
AS

/*
	Created: 20160705@Bobby
	Task : Get ticket detail from table betransRnG (Microgaming RNG Game)
	DB: DBEXT.bodb02
	Revisions:
		- 20160705@Bobby: Support One RNG 

	Parameters:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 5

	DELETE FROM @SportBettype
	WHERE ProductID NOT IN (6, 17, 22)	-- Support Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge
		OR (ProductID = 6 AND SubProduct = '')

	DECLARE @tmpStatus TABLE (statusId TINYINT)

	INSERT INTO @tmpStatus
	SELECT 111 UNION ALL
	SELECT 112 UNION ALL
	SELECT 113

	-- Get ticket
	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.playercomm AS commission,
			brng.spositiontaking,
			brng.mpositiontaking,
			brng.apositiontaking,
			brng.swinlost,
			brng.mwinlost,
			brng.awinlost,
			brng.sdiscount,
			brng.adiscount,
			brng.discount,
			(brng.scomm - brng.acomm) AS scomm,
			(brng.acomm - brng.comm) AS acomm,
			(brng.comm - brng.playercomm) AS comm,
			brng.ip,
			brng.transdesc,
			CASE
				WHEN sbt.productID IN (6, 17, 22) THEN brng.TranId3rd
				ELSE ''
			END AS BetCheck,
			'' AS MatchCode
		FROM dbo.bettransRnG AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId 
			AND brng.RefNo = @RefNo
			AND brng.statusID IN (SELECT statusId FROM @tmpStatus)
	END
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.playercomm AS commission,
			brng.spositiontaking,
			brng.mpositiontaking,
			brng.apositiontaking,
			brng.swinlost,
			brng.mwinlost,
			brng.awinlost,
			brng.sdiscount,
			brng.adiscount,
			brng.discount,
			(brng.scomm - brng.acomm) AS scomm,
			(brng.acomm - brng.comm) AS acomm,
			(brng.comm - brng.playercomm) AS comm,
			brng.ip,
			brng.transdesc,
			CASE
				WHEN sbt.productID IN (6, 17, 22) THEN brng.TranId3rd
				ELSE ''
			END AS BetCheck,
			'' AS MatchCode
		FROM dbo.bettransRnG14 AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
	END
	ELSE IF EXISTS ( SELECT 1 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.playercomm AS commission,
			brng.spositiontaking,
			brng.mpositiontaking,
			brng.apositiontaking,
			brng.swinlost,
			brng.mwinlost,
			brng.awinlost,
			brng.sdiscount,
			brng.adiscount,
			brng.discount,
			(brng.scomm - brng.acomm) AS scomm,
			(brng.acomm - brng.comm) AS acomm,
			(brng.comm - brng.playercomm) AS comm,
			brng.ip,
			brng.transdesc,
			CASE
				WHEN sbt.productID IN (6, 17, 22) THEN brng.TranId3rd
				ELSE ''
			END AS BetCheck,
			'' AS MatchCode
		FROM DBARC.bodb_Archive.dbo.bettransRnG_bk AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
	END

	RETURN
END
GO

GRANT	VIEW DEFINITION	ON	Aff_BetList_RNG_Detail	TO	vnteam
GRANT	EXECUTE	ON	Aff_BetList_RNG_Detail	TO	bodbDownlineNet
GRANT	EXECUTE	ON	Aff_BetList_RNG_Detail	TO	bodbAdminNet
GO
