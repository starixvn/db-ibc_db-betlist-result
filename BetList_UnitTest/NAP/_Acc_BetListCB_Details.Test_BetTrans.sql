USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetListCB_Details].[Test_BetTrans]    Script Date: 1/10/2017 9:12:45 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetListCB_Details].[Test_BetTrans]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		TransId		BIGINT,
		TransDate	DATETIME,
		BetType		INT,
		Sold		SMALLMONEY,
		WinLost		MONEY,
		StatusId	TINYINT,
		Status		NVARCHAR(10),
		SDiscount	SMALLMONEY,
		ADiscount	SMALLMONEY,
		Discount	SMALLMONEY,
		SComm		MONEY,
		AComm		MONEY,
		Comm		MONEY,
		OddsSpread	MONEY
	)

	DECLARE @TransId			BIGINT,
		@RefNo					BIGINT,
		@CustId					INT,
		@ExpectedNumOfSubTicket	TINYINT

	SELECT TOP(1)
		@TransId = b.transid,
		@RefNo = b.refno,
		@CustId = b.custid
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.bettype = 18000

	SELECT @ExpectedNumOfSubTicket = COUNT(*)
	FROM
		(
			SELECT b.transid
			FROM bodb02.dbo.bettransm AS b WITH (NOLOCK)
			WHERE b.refno = @RefNo
				AND b.bettype BETWEEN 18001 AND 18006

			UNION

			SELECT b.transid
			FROM bodb02.dbo.bettransm14 AS b WITH (NOLOCK)
			WHERE b.refno = @RefNo
				AND b.bettype BETWEEN 18001 AND 18006

			UNION

			SELECT b.transid
			FROM DBARC.bodb_Archive.dbo.bettransm AS b WITH (NOLOCK)
			WHERE b.refno = @RefNo
				AND b.bettype BETWEEN 18001 AND 18006
		) AS tmp

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetListCB_Details] 
							@RefNo = ' + CONVERT(VARCHAR(20), @RefNo) + ',
							@CustId = ' + CONVERT(VARCHAR(10), @CustId)

		INSERT @Data
		EXEC sp_executesql @Command

		DECLARE @NumOfSubTicket	TINYINT

		SELECT @NumOfSubTicket = COUNT(*)
		FROM @Data

		-- Assert
		EXEC tSQLt.AssertEquals
			@Expected = @ExpectedNumOfSubTicket,
			@Actual = @NumOfSubTicket,
			@Message = @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail @Message0 = 'No available test data'
	END
END;

GO
