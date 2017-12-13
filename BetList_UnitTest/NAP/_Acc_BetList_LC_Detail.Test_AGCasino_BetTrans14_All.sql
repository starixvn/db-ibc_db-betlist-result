USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetList_LC_Detail].[Test_AGCasino_BetTrans14_All]    Script Date: 1/10/2017 8:42:52 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetList_LC_Detail].[Test_AGCasino_BetTrans14_All]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		RowNum			INT,
		TransId			BIGINT,
		SportType		INT,
		BetType			INT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		Status			NVARCHAR(10),
		StatusId		TINYINT,
		Odds			MONEY,
		Currency		NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		Commission		MONEY,
		SPositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		APositionTaking SMALLMONEY,
		SWinLost		MONEY,
		MWinLost		MONEY,
		AWinLost		MONEY,
		SDiscount		DECIMAL(9, 8),
		ADiscount		DECIMAL(9, 8),
		Discount		DECIMAL(9, 8),
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		Ip				NVARCHAR(15),
		TransDesc		NVARCHAR(300),
		BetCheck		NVARCHAR(50),
		MatchCode		VARCHAR(50)
	)

	DECLARE @RefNo	BIGINT,
		@CustID		INT,
		@TransType	TINYINT = 0,
		@TransId	BIGINT

	SELECT TOP(1)
		@RefNo = b.transid,
		@CustID = b.custid,
		@TransId = brng.transid
	FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettransLC14 AS brng WITH (NOLOCK) ON brng.refno = b.transid
	WHERE b.bettype BETWEEN 1800 AND 1804

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetList_LC_Detail]
							@RefNo = ' + CONVERT(VARCHAR(20), @RefNo) + ',
							@CustId = ' + CONVERT(VARCHAR(10), @CustID) + ',
							@TransType = ' + CONVERT(VARCHAR(3), @TransType)

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		DECLARE @Actual INT

		SELECT @Actual = COUNT(*)
		FROM @Data
		WHERE TransId = @TransId

		-- Assert
		EXEC tSQLt.AssertEquals
			@Expected = 1,
			@Actual = @Actual,
			@Message = @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail @Message0 = 'No available test data'
	END
END;

GO
