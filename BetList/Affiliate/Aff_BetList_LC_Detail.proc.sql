/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Acc_BetList_LC_Detail]    Script Date: 10/12/2015 3:31:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Aff_BetList_LC_Detail]
	@RefNo		BIGINT,
	@CustId		INT
AS

/*
	Created: 20160705@Bobby
	Task : Get ticket detail from table betransLC (AG Casino)
	DB: DBEXT.bodb02
	Revisions:
		- 20160705@Bobby: Support One RNG 

	Parameters:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4

	DELETE FROM @SportBettype
	WHERE ProductID NOT IN (11, 21)	-- Support AG Casino, AllBet only

	DECLARE @tmpStatus TABLE (statusId TINYINT)
	
	INSERT INTO @tmpStatus
	SELECT 111 UNION ALL
	SELECT 112 UNION ALL
	SELECT 113 

	-- Get ticket
	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.playercomm AS commission,
			blc.spositiontaking,
			blc.mpositiontaking,
			blc.apositiontaking,
			blc.swinlost,
			blc.mwinlost,
			blc.awinlost,
			blc.sdiscount,
			blc.adiscount,
			blc.discount,
			(blc.scomm - blc.acomm) AS scomm,
			(blc.acomm - blc.comm) AS acomm,
			(blc.comm - blc.playercomm) AS comm,
			blc.ip,
			blc.transdesc,
			CASE
				WHEN sbt.productID IN (21) THEN blc.TranId3rd
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode
		FROM dbo.bettransLC AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
		WHERE blc.custid = @CustId 
			AND blc.RefNo = @RefNo
			AND blc.statusID IN (SELECT statusId FROM @tmpStatus)
	END
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.playercomm AS commission,
			blc.spositiontaking,
			blc.mpositiontaking,
			blc.apositiontaking,
			blc.swinlost,
			blc.mwinlost,
			blc.awinlost,
			blc.sdiscount,
			blc.adiscount,
			blc.discount,
			(blc.scomm - blc.acomm) AS scomm,
			(blc.acomm - blc.comm) AS acomm,
			(blc.comm - blc.playercomm) AS comm,
			blc.ip,
			blc.transdesc,
			CASE
				WHEN sbt.productID IN (21) THEN blc.TranId3rd
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode
		FROM dbo.bettransLC14 AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
		WHERE blc.custid = @CustId AND blc.RefNo = @RefNo
	END
	ELSE IF EXISTS ( SELECT 1 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.playercomm AS commission,
			blc.spositiontaking,
			blc.mpositiontaking,
			blc.apositiontaking,
			blc.swinlost,
			blc.mwinlost,
			blc.awinlost,
			blc.sdiscount,
			blc.adiscount,
			blc.discount,
			(blc.scomm - blc.acomm) AS scomm,
			(blc.acomm - blc.comm) AS acomm,
			(blc.comm - blc.playercomm) AS comm,
			blc.ip,
			blc.transdesc,
			CASE
				WHEN sbt.productID IN (21) THEN blc.TranId3rd
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode
		FROM DBARC.bodb_Archive.dbo.bettransLC_bk AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
		WHERE blc.custid = @CustId AND blc.RefNo = @RefNo
	END
	
	RETURN
	
END


GO
GRANT	VIEW DEFINITION	ON	Aff_BetList_LC_Detail	TO	vnteam
GRANT	EXECUTE	ON	Aff_BetList_LC_Detail	TO	bodbDownlineNet
GRANT	EXECUTE	ON	Aff_BetList_LC_Detail	TO	bodbAdminNet
GO
