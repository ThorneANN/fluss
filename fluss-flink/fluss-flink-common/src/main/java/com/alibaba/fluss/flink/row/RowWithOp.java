/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.alibaba.fluss.flink.row;

import com.alibaba.fluss.row.InternalRow;

import javax.annotation.Nullable;

import java.util.Objects;

import static com.alibaba.fluss.utils.Preconditions.checkNotNull;

/**
 * A wrapper class that associates an {@link InternalRow} with an {@link OperationType} for use in
 * Fluss-Flink data processing.
 *
 * <p>This class is used to represent a row of data along with its corresponding operation type,
 * such as APPEND, UPSERT, or DELETE, as defined by {@link OperationType}.
 *
 * @see InternalRow
 * @see OperationType
 */
public class RowWithOp {
    /** The internal row data. */
    private final InternalRow row;

    /** The type of operation associated with this row (e.g., APPEND, UPSERT, DELETE). */
    private final OperationType opType;

    /**
     * Constructs a {@code RowWithOp} with the specified internal row and operation type.
     *
     * @param row the internal row data (must not be null)
     * @param opType the operation type (must not be null)
     * @throws NullPointerException if {@code row} or {@code opType} is null
     */
    public RowWithOp(InternalRow row, @Nullable OperationType opType) {
        this.row = checkNotNull(row, "row cannot be null");
        this.opType = checkNotNull(opType, "opType cannot be null");
    }

    /**
     * Returns the internal row data.
     *
     * @return the internal row
     */
    public InternalRow getRow() {
        return row;
    }

    /**
     * Returns the operation type associated with this row.
     *
     * @return the operation type
     */
    public OperationType getOperationType() {
        return opType;
    }

    /**
     * Indicates whether some other object is "equal to" this one. Two {@code RowWithOp} objects are
     * considered equal if their internal rows and operation types are equal.
     *
     * @param o the reference object with which to compare
     * @return {@code true} if this object is the same as the obj argument; {@code false} otherwise
     */
    @Override
    public boolean equals(Object o) {
        if (o == null || getClass() != o.getClass()) {
            return false;
        }
        RowWithOp rowWithOp = (RowWithOp) o;
        return Objects.equals(row, rowWithOp.row) && opType == rowWithOp.opType;
    }

    /**
     * Returns a hash code value for the object.
     *
     * @return a hash code value for this object
     */
    @Override
    public int hashCode() {
        return Objects.hash(row, opType);
    }
}
